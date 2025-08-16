import Foundation
import CoreData

// Extended insights structure that includes action items, decisions, and questions
struct ExtendedMeetingInsights: Codable {
    let executiveSummary: String
    let keyPoints: [String]
    let criticalInfo: String?
    let unresolvedTopics: [String]
    let risks: [String]
    let followUpItems: [String]
    let actionItems: [LFM2Prompts.ActionItem]
    let decisions: [LFM2Prompts.Decision]
    let questions: [LFM2Prompts.Question]
}

class MeetingEnhancementService {
    static let shared = MeetingEnhancementService()
    private let lfm2Manager = LFM2Manager.shared
    private let enhancementQueue = DispatchQueue(label: "com.vera.enhancement", qos: .background)
    
    private init() {}
    
    // MAIN METHOD: Single comprehensive analysis when recording ends
    func analyzeCompletedMeeting(_ meeting: Meeting, context: NSManagedObjectContext) async throws {
        guard let transcript = meeting.transcript, !transcript.isEmpty else {
            print("⚠️ No transcript available for analysis")
            return
        }
        
        print("🤖 Starting comprehensive meeting analysis...")
        
        // Update status on main thread
        await MainActor.run {
            meeting.processingStatus = ProcessingStatus.processing.rawValue
            try? context.save()
        }
        
        do {
            // Ensure model is loaded
            if !lfm2Manager.isLoaded {
                print("📦 Loading LFM2 model...")
                try await lfm2Manager.loadModel()
            }
            
            // Simple text prompt for meeting summary
            let prompt = """
            Analyze this meeting transcript and provide a comprehensive summary.
            
            Meeting Transcript:
            \(transcript)
            
            \(meeting.rawNotes != nil && !meeting.rawNotes!.isEmpty ? "User Notes: \(meeting.rawNotes!)\n" : "")
            
            Please provide:
            1. Executive Summary (2-3 sentences)
            2. Key Points Discussed
            3. Action Items (if any)
            4. Decisions Made (if any)
            5. Follow-up Required (if any)
            
            Format your response as clear, readable text with sections.
            """
            
            // Get text response from LFM2
            let analysisText = try await lfm2Manager.generate(
                prompt: prompt,
                configuration: .summary
            )
            
            // Process and store all results
            await MainActor.run {
                // Store the text analysis as enhanced notes
                meeting.enhancedNotes = analysisText
                
                // Create basic insights from the text (we can parse it later if needed)
                meeting.meetingInsights = MeetingInsights(
                    executiveSummary: "Meeting analyzed by LFM2",
                    keyPoints: [],
                    criticalInfo: nil,
                    unresolvedTopics: [],
                    risks: [],
                    followUpItems: []
                )
                
                meeting.processingStatus = ProcessingStatus.completed.rawValue
                meeting.lastProcessedDate = Date()
                
                do {
                    try context.save()
                    print("✅ Meeting analysis completed successfully")
                    print("   - Response length: \(analysisText.count) characters")
                } catch {
                    print("❌ Failed to save analyzed meeting: \(error)")
                }
            }
            
        } catch {
            await MainActor.run {
                meeting.processingStatus = ProcessingStatus.failed.rawValue
                try? context.save()
            }
            print("❌ Meeting analysis failed: \(error)")
            throw error
        }
    }
    
    // Removed formatAnalysisAsSummary - no longer needed for text response
    /*
    private func formatAnalysisAsSummary(_ analysis: LFM2Prompts.MeetingAnalysisResponse) -> String {
        var summary = "## Executive Summary\n\(analysis.executiveSummary)\n\n"
        
        if !analysis.keyPoints.isEmpty {
            summary += "## Key Points\n"
            for point in analysis.keyPoints {
                summary += "• \(point)\n"
            }
            summary += "\n"
        }
        
        if !analysis.actionItems.isEmpty {
            summary += "## Action Items\n"
            for item in analysis.actionItems {
                let actionText = "→ \(item.task)"
                    + (item.owner != nil ? " (\(item.owner!))" : "")
                    + (item.deadline != nil ? " - Due: \(item.deadline!)" : "")
                    + " [\(item.priority)]\n"
                summary += actionText
            }
            summary += "\n"
        }
        
        if !analysis.decisions.isEmpty {
            summary += "## Decisions\n"
            for decision in analysis.decisions {
                summary += "• \(decision.decision)\n"
                if !decision.context.isEmpty {
                    summary += "  Context: \(decision.context)\n"
                }
                if !decision.impact.isEmpty {
                    summary += "  Impact: \(decision.impact)\n"
                }
            }
            summary += "\n"
        }
        
        if !analysis.questions.isEmpty {
            summary += "## Open Questions\n"
            for question in analysis.questions {
                summary += "❓ \(question.question)\n"
                if let assignedTo = question.assignedTo {
                    summary += "  Assigned to: \(assignedTo)\n"
                }
            }
            summary += "\n"
        }
        
        if !analysis.risks.isEmpty {
            summary += "## Risks Identified\n"
            for risk in analysis.risks {
                summary += "⚠️ \(risk)\n"
            }
            summary += "\n"
        }
        
        if !analysis.followUp.isEmpty {
            summary += "## Follow-up Required\n"
            for item in analysis.followUp {
                summary += "• \(item)\n"
            }
        }
        
        return summary
    }
    */
    
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
            
            async let summaryTask = generateEnhancedSummary(transcript: transcript, notes: meeting.rawNotes)
            async let insightsTask = generateInsights(from: transcript)
            
            let (summary, insights) = try await (
                summaryTask,
                insightsTask
            )
            
            await MainActor.run {
                meeting.enhancedNotes = summary
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
    
    func generateEnhancedSummary(transcript: String, notes: String?) async throws -> String {
        // Use the unified meeting analysis prompt
        let prompt = LFM2Prompts.analyzeMeeting(transcript: transcript, userNotes: notes)
        
        let response = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .summary,
            responseType: LFM2Prompts.MeetingAnalysisResponse.self
        )
        
        var summary = "## Executive Summary\n\(response.executiveSummary)\n\n"
        
        if !response.keyPoints.isEmpty {
            summary += "## Key Points\n"
            for point in response.keyPoints {
                summary += "• \(point)\n"
            }
            summary += "\n"
        }
        
        if !response.actionItems.isEmpty {
            summary += "## Action Items\n"
            for item in response.actionItems {
                let actionText = "→ \(item.task)"
                    + (item.owner != nil ? " (\(item.owner!))" : "")
                    + (item.deadline != nil ? " - Due: \(item.deadline!)" : "")
                    + " [\(item.priority)]\n"
                summary += actionText
            }
            summary += "\n"
        }
        
        if !response.decisions.isEmpty {
            summary += "## Decisions\n"
            for decision in response.decisions {
                summary += "• \(decision.decision)\n"
                if !decision.context.isEmpty {
                    summary += "  Context: \(decision.context)\n"
                }
                if !decision.impact.isEmpty {
                    summary += "  Impact: \(decision.impact)\n"
                }
            }
            summary += "\n"
        }
        
        if !response.questions.isEmpty {
            summary += "## Open Questions\n"
            for question in response.questions {
                summary += "❓ \(question.question)\n"
                if let assignedTo = question.assignedTo {
                    summary += "  Assigned to: \(assignedTo)\n"
                }
            }
            summary += "\n"
        }
        
        if !response.risks.isEmpty {
            summary += "## Risks Identified\n"
            for risk in response.risks {
                summary += "⚠️ \(risk)\n"
            }
            summary += "\n"
        }
        
        if !response.followUp.isEmpty {
            summary += "## Follow-up Required\n"
            for item in response.followUp {
                summary += "• \(item)\n"
            }
        }
        
        return summary
    }
    
    func generateInsights(from transcript: String) async throws -> MeetingInsights {
        // Use the unified meeting analysis prompt
        let prompt = LFM2Prompts.analyzeMeeting(transcript: transcript, userNotes: nil)
        
        let response = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .summary,
            responseType: LFM2Prompts.MeetingAnalysisResponse.self
        )
        
        return MeetingInsights(
            executiveSummary: response.executiveSummary,
            keyPoints: response.keyPoints.compactMap { keyPoint in
                keyPoint.point ?? keyPoint.details
            },
            criticalInfo: response.criticalInfo,
            unresolvedTopics: response.unresolvedTopics,
            risks: response.risks.compactMap { risk in
                risk.risk
            },
            followUpItems: response.followUp.compactMap { item in
                item.item
            }
        )
    }
    
    func processInChunks(transcript: String, chunkSize: Int = 5000) async throws {
        let words = transcript.split(separator: " ")
        let chunks = words.chunks(ofCount: chunkSize)
        
        for (index, chunk) in chunks.enumerated() {
            let chunkText = chunk.joined(separator: " ")
            print("📝 Processing chunk \(index + 1) of \(chunks.count)")
            _ = try await generateEnhancedSummary(transcript: chunkText, notes: nil)
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