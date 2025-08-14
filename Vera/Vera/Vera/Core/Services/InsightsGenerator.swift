import Foundation

class InsightsGenerator {
    private let lfm2Manager = LFM2Manager.shared
    
    private let decisionKeywords = [
        "decided", "agreed", "confirmed", "approved",
        "will go with", "chose", "selected", "determined",
        "resolved", "concluded", "finalized", "settled"
    ]
    
    private let questionIndicators = [
        "?", "what", "when", "where", "who", "why", "how",
        "should we", "could we", "can we", "do we",
        "need to know", "unclear", "not sure", "maybe"
    ]
    
    private let riskIndicators = [
        "risk", "concern", "worried", "problem", "issue",
        "challenge", "difficult", "blocker", "dependency",
        "critical", "urgent", "careful", "watch out"
    ]
    
    func generateInsights(from transcript: String, withNotes notes: String? = nil) async throws -> MeetingInsights {
        async let aiInsights = generateWithAI(transcript: transcript, notes: notes)
        async let extractedDecisions = extractDecisions(from: transcript)
        async let extractedQuestions = extractQuestions(from: transcript)
        async let extractedRisks = extractRisks(from: transcript)
        
        let (baseInsights, decisions, questions, risks) = try await (
            aiInsights,
            extractedDecisions,
            extractedQuestions,
            extractedRisks
        )
        
        return combineInsights(
            base: baseInsights,
            decisions: decisions,
            questions: questions,
            risks: risks
        )
    }
    
    private func generateWithAI(transcript: String, notes: String?) async throws -> MeetingInsights {
        let prompt = """
        Analyze this meeting and extract comprehensive insights.
        
        Meeting Transcript:
        \(transcript)
        
        \(notes.map { "User Notes:\n\($0)\n" } ?? "")
        
        Generate insights including:
        1. Executive Summary - 2-3 sentences capturing meeting essence
        2. Key Points - Most important discussion items (max 5)
        3. Critical Information - Urgent or time-sensitive items
        4. Unresolved Topics - Items needing further discussion
        5. Risks/Concerns - Potential problems mentioned
        6. Follow-up Items - Specific next steps
        
        Focus on actionable intelligence, not just summary.
        
        Return as JSON with these exact fields:
        {
          "executiveSummary": "...",
          "keyPoints": ["..."],
          "criticalInfo": "..." or null,
          "unresolvedTopics": ["..."],
          "risks": ["..."],
          "followUpItems": ["..."]
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
            keyPoints: Array(response.keyPoints.prefix(5)),
            criticalInfo: response.criticalInfo,
            unresolvedTopics: response.unresolvedTopics,
            risks: response.risks,
            followUpItems: response.followUpItems
        )
    }
    
    private func extractDecisions(from transcript: String) async throws -> [KeyDecision] {
        let prompt = """
        Extract all key decisions from this meeting.
        
        Transcript:
        \(transcript)
        
        Look for:
        - Explicit decisions ("We decided to...")
        - Agreements ("Everyone agreed that...")
        - Choices made ("We'll go with option A")
        - Plans confirmed ("The plan is to...")
        
        For each decision provide:
        {
          "decision": "Clear statement of what was decided",
          "context": "Why this decision was made",
          "impact": "Who/what this affects",
          "timestamp": "ISO8601 timestamp"
        }
        
        Return as JSON array. Be thorough.
        """
        
        let responses = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .extraction,
            responseType: [LFM2Manager.DecisionResponse].self
        )
        
        return responses.map { response in
            KeyDecision(
                decision: response.decision,
                context: response.context,
                impact: response.impact,
                timestamp: ISO8601DateFormatter().date(from: response.timestamp) ?? Date()
            )
        }
    }
    
    private func extractQuestions(from transcript: String) async throws -> [Question] {
        let prompt = """
        Identify all questions and items needing clarification.
        
        Transcript:
        \(transcript)
        
        Find:
        - Direct questions asked
        - Items marked for research
        - Unclear points needing clarification
        - Decisions pending more information
        - Topics to revisit later
        
        For each question provide:
        {
          "question": "The question or unclear item",
          "context": "Why this needs answering",
          "assignedTo": "Who should respond (if mentioned)",
          "urgency": "high|medium|low"
        }
        
        Return as JSON array.
        """
        
        let responses = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .extraction,
            responseType: [LFM2Manager.QuestionResponse].self
        )
        
        return responses.map { response in
            Question(
                question: response.question,
                context: response.context,
                needsFollowUp: true,
                assignedTo: response.assignedTo,
                urgency: Question.Urgency(rawValue: response.urgency) ?? .medium
            )
        }
    }
    
    private func extractRisks(from transcript: String) async throws -> [String] {
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var risks: [String] = []
        
        for sentence in sentences {
            let lowercased = sentence.lowercased()
            
            if riskIndicators.contains(where: { lowercased.contains($0) }) {
                let cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count > 10 && cleaned.count < 300 {
                    risks.append(cleaned)
                }
            }
        }
        
        let prompt = """
        Extract risks and concerns from these sentences:
        \(risks.joined(separator: "\n"))
        
        Return as JSON array of strings, each being a clear risk statement.
        Remove duplicates and combine related risks.
        Maximum 10 risks.
        """
        
        if !risks.isEmpty {
            do {
                let aiRisks = try await lfm2Manager.generateJSON(
                    prompt: prompt,
                    configuration: .extraction,
                    responseType: [String].self
                )
                return Array(aiRisks.prefix(10))
            } catch {
                return Array(risks.prefix(5))
            }
        }
        
        return []
    }
    
    private func combineInsights(
        base: MeetingInsights,
        decisions: [KeyDecision],
        questions: [Question],
        risks: [String]
    ) -> MeetingInsights {
        var combinedRisks = base.risks
        for risk in risks {
            if !combinedRisks.contains(where: { $0.lowercased().contains(risk.lowercased()) }) {
                combinedRisks.append(risk)
            }
        }
        
        var unresolvedTopics = base.unresolvedTopics
        for question in questions.prefix(3) {
            if !unresolvedTopics.contains(where: { $0.lowercased().contains(question.question.lowercased()) }) {
                unresolvedTopics.append(question.question)
            }
        }
        
        var followUpItems = base.followUpItems
        for decision in decisions where decision.context?.lowercased().contains("follow") ?? false {
            if !followUpItems.contains(where: { $0.lowercased().contains(decision.decision.lowercased()) }) {
                followUpItems.append(decision.decision)
            }
        }
        
        return MeetingInsights(
            executiveSummary: base.executiveSummary,
            keyPoints: base.keyPoints,
            criticalInfo: base.criticalInfo,
            unresolvedTopics: Array(unresolvedTopics.prefix(10)),
            risks: Array(combinedRisks.prefix(10)),
            followUpItems: Array(followUpItems.prefix(10))
        )
    }
    
    func generateQuickSummary(from transcript: String) -> String {
        let words = transcript.split(separator: " ")
        let sentenceCount = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?")).count
        
        var summary = "Meeting with \(sentenceCount) discussion points"
        
        if words.count > 100 {
            summary += " covering multiple topics"
        }
        
        let hasDecisions = decisionKeywords.contains { keyword in
            transcript.lowercased().contains(keyword)
        }
        if hasDecisions {
            summary += " including key decisions"
        }
        
        let hasQuestions = questionIndicators.contains { indicator in
            transcript.lowercased().contains(indicator)
        }
        if hasQuestions {
            summary += " with open questions"
        }
        
        return summary
    }
}