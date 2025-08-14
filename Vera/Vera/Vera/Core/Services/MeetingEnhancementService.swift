import Foundation
import CoreData

class MeetingEnhancementService {
    static let shared = MeetingEnhancementService()
    private let lfm2Manager = LFM2Manager.shared
    private let enhancementQueue = DispatchQueue(label: "com.vera.enhancement", qos: .background)
    
    private init() {}
    
    func enhanceMeeting(_ meeting: Meeting, context: NSManagedObjectContext) async throws {
        guard let transcript = meeting.transcript, !transcript.isEmpty else {
            print("⚠️ No transcript available for enhancement")
            return
        }
        
        meeting.processingStatus = ProcessingStatus.processing.rawValue
        meeting.lastProcessedDate = Date()
        try? context.save()
        
        do {
            if !lfm2Manager.isLoaded {
                try await lfm2Manager.loadModel()
                await lfm2Manager.warmupModel()
            }
            
            async let summaryTask = generateSummary(transcript: transcript, notes: meeting.rawNotes)
            async let actionItemsTask = extractActionItems(from: transcript)
            async let decisionsTask = extractKeyDecisions(from: transcript)
            async let questionsTask = identifyQuestions(from: transcript)
            async let insightsTask = generateInsights(from: transcript)
            
            let (summary, actionItems, decisions, questions, insights) = try await (
                summaryTask,
                actionItemsTask,
                decisionsTask,
                questionsTask,
                insightsTask
            )
            
            await MainActor.run {
                meeting.enhancedNotes = summary
                meeting.actionItemsArray = actionItems
                meeting.keyDecisionsArray = decisions
                meeting.questionsArray = questions
                meeting.meetingInsights = insights
                meeting.processingStatus = ProcessingStatus.completed.rawValue
                meeting.lastProcessedDate = Date()
                
                do {
                    try context.save()
                    print("✅ Meeting enhancement completed successfully")
                } catch {
                    print("❌ Failed to save enhanced meeting: \(error)")
                }
            }
            
        } catch {
            await MainActor.run {
                meeting.processingStatus = ProcessingStatus.failed.rawValue
                try? context.save()
            }
            throw error
        }
    }
    
    func generateSummary(transcript: String, notes: String?) async throws -> String {
        let prompt = """
        You are analyzing a meeting transcript. Generate a comprehensive yet concise summary.
        
        Meeting Transcript:
        \(transcript)
        
        User Notes (if any):
        \(notes ?? "None")
        
        Instructions:
        1. Create an executive summary (2-3 sentences)
        2. List key discussion points (max 5 bullet points)
        3. Highlight any critical information
        4. Note any unresolved topics
        
        Format as structured JSON:
        {
          "executiveSummary": "...",
          "keyPoints": ["point1", "point2", ...],
          "criticalInfo": "...",
          "unresolvedTopics": ["topic1", ...]
        }
        """
        
        let response = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .summary,
            responseType: LFM2Manager.SummaryResponse.self
        )
        
        var summary = "## Executive Summary\n\(response.executiveSummary)\n\n"
        
        if !response.keyPoints.isEmpty {
            summary += "## Key Points\n"
            for point in response.keyPoints {
                summary += "• \(point)\n"
            }
            summary += "\n"
        }
        
        if let critical = response.criticalInfo {
            summary += "## Critical Information\n\(critical)\n\n"
        }
        
        if !response.unresolvedTopics.isEmpty {
            summary += "## Unresolved Topics\n"
            for topic in response.unresolvedTopics {
                summary += "• \(topic)\n"
            }
        }
        
        return summary
    }
    
    func extractActionItems(from transcript: String) async throws -> [ActionItem] {
        let prompt = """
        Extract ALL action items from this meeting transcript.
        
        Transcript:
        \(transcript)
        
        For each action item, identify:
        - Task: Clear, actionable description
        - Owner: Person responsible (if mentioned)
        - Deadline: Any timeframe mentioned (today, tomorrow, next week, specific date)
        - Priority: Infer from context (urgent, high, medium, low)
        - Context: Brief note about why this task is needed
        
        Return as JSON array:
        [
          {
            "task": "...",
            "owner": "name or null",
            "deadline": "ISO8601 date string or null",
            "priority": "high|medium|low",
            "context": "..."
          }
        ]
        
        Look for phrases like:
        - "I'll do...", "Can you...", "We need to..."
        - "By [date]", "Before [event]", "ASAP"
        - "Action item:", "TODO:", "Next step:"
        """
        
        let responses = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .extraction,
            responseType: [LFM2Manager.ActionItemResponse].self
        )
        
        return responses.map { response in
            let deadline: Date? = response.deadline.flatMap { ISO8601DateFormatter().date(from: $0) }
            let priority = ActionItem.Priority(rawValue: response.priority) ?? .medium
            
            return ActionItem(
                task: response.task,
                owner: response.owner,
                deadline: deadline,
                isCompleted: false,
                priority: priority,
                context: response.context
            )
        }
    }
    
    func extractKeyDecisions(from transcript: String) async throws -> [KeyDecision] {
        let prompt = """
        Identify all decisions made during this meeting.
        
        Transcript:
        \(transcript)
        
        Extract decisions where the team:
        - Agreed on something
        - Chose between options
        - Confirmed a plan
        - Rejected an approach
        
        For each decision return JSON:
        {
          "decision": "What was decided",
          "context": "Why this decision was made",
          "impact": "Who/what this affects",
          "timestamp": "ISO8601 timestamp"
        }
        
        Look for: "decided", "agreed", "will go with", "confirmed", "chose"
        """
        
        let responses = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .extraction,
            responseType: [LFM2Manager.DecisionResponse].self
        )
        
        return responses.map { response in
            let timestamp = ISO8601DateFormatter().date(from: response.timestamp) ?? Date()
            
            return KeyDecision(
                decision: response.decision,
                context: response.context,
                impact: response.impact,
                timestamp: timestamp
            )
        }
    }
    
    func identifyQuestions(from transcript: String) async throws -> [Question] {
        let prompt = """
        Identify questions and items needing follow-up from this meeting.
        
        Transcript:
        \(transcript)
        
        Find:
        1. Unanswered questions
        2. Items marked for research
        3. Decisions pending information
        4. Topics to revisit
        
        Format as JSON:
        {
          "question": "The question or item",
          "context": "Why this came up",
          "assignedTo": "Who should follow up (if mentioned)",
          "urgency": "high|medium|low"
        }
        """
        
        let responses = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .extraction,
            responseType: [LFM2Manager.QuestionResponse].self
        )
        
        return responses.map { response in
            let urgency = Question.Urgency(rawValue: response.urgency) ?? .medium
            
            return Question(
                question: response.question,
                context: response.context,
                needsFollowUp: true,
                assignedTo: response.assignedTo,
                urgency: urgency
            )
        }
    }
    
    func generateInsights(from transcript: String) async throws -> MeetingInsights {
        let prompt = """
        Analyze this meeting for important insights and generate a comprehensive summary.
        
        Transcript:
        \(transcript)
        
        Generate:
        1. Executive Summary (2-3 sentences capturing the essence)
        2. Key Points (maximum 5 bullet points)
        3. Critical Information (if any)
        4. Unresolved Topics
        5. Risks or Concerns
        6. Follow-up Items
        
        Return as JSON:
        {
          "executiveSummary": "...",
          "keyPoints": ["point1", "point2", ...],
          "criticalInfo": "...",
          "unresolvedTopics": ["topic1", ...],
          "risks": ["risk1", ...],
          "followUpItems": ["item1", ...]
        }
        """
        
        struct InsightsResponse: Codable {
            let executiveSummary: String
            let keyPoints: [String]
            let criticalInfo: String?
            let unresolvedTopics: [String]
            let risks: [String]
            let followUpItems: [String]
        }
        
        let response = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .summary,
            responseType: InsightsResponse.self
        )
        
        return MeetingInsights(
            executiveSummary: response.executiveSummary,
            keyPoints: response.keyPoints,
            criticalInfo: response.criticalInfo,
            unresolvedTopics: response.unresolvedTopics,
            risks: response.risks,
            followUpItems: response.followUpItems
        )
    }
    
    func processInChunks(transcript: String, chunkSize: Int = 5000) async throws {
        let words = transcript.split(separator: " ")
        let chunks = words.chunks(ofCount: chunkSize)
        
        for (index, chunk) in chunks.enumerated() {
            let chunkText = chunk.joined(separator: " ")
            print("📝 Processing chunk \(index + 1) of \(chunks.count)")
            _ = try await generateSummary(transcript: chunkText, notes: nil)
        }
    }
}

private extension Array {
    func chunks(ofCount count: Int) -> [[Element]] {
        var chunks: [[Element]] = []
        var currentIndex = 0
        
        while currentIndex < self.count {
            let endIndex = Swift.min(currentIndex + count, self.count)
            chunks.append(Array(self[currentIndex..<endIndex]))
            currentIndex = endIndex
        }
        
        return chunks
    }
}