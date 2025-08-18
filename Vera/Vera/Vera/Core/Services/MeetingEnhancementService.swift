import Foundation
import CoreData

// Simple text-based enhancement for hackathon
// No complex JSON parsing or structured data - just plain text analysis

class MeetingEnhancementService {
    static let shared = MeetingEnhancementService()
    private let lfm2Manager = LFM2Manager.shared
    private let enhancementQueue = DispatchQueue(label: "com.vera.enhancement", qos: .background)
    
    private init() {}
    
    // Simple text-based analysis - returns plain text summary
    func analyzeCompletedMeeting(_ meeting: Meeting, context: NSManagedObjectContext) async throws {
        print("🤖 Starting comprehensive meeting analysis...")
        
        guard let transcript = meeting.transcript, !transcript.isEmpty else {
            print("⚠️ No transcript available for analysis")
            return
        }
        
        // Mark as processing
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
            
            // First: Generate title and preview
            let titlePrompt = """
            Based on this conversation, create:
            1. A concise, descriptive title (3-6 words)
            2. A one-sentence preview that captures the main topic or purpose
            
            Format exactly as:
            Title: [your title here]
            Preview: [your preview here]
            
            Content:
            \(transcript)
            
            \(meeting.rawNotes != nil && !meeting.rawNotes!.isEmpty ? "Additional context: \(meeting.rawNotes!)\n" : "")
            """
            
            let titleConfig = LFM2Manager.ModelConfiguration(
                maxTokens: 150,  // Short for title/preview
                temperature: 0.4,  // Slightly creative
                topP: 0.9,
                streamingEnabled: false
            )
            
            print("🏷️ Generating title and preview...")
            let titleResponse = try await lfm2Manager.generate(
                prompt: titlePrompt,
                configuration: titleConfig
            )
            
            // Parse title and preview
            var generatedTitle = meeting.title  // Keep existing title as fallback
            var generatedPreview = ""
            
            let lines = titleResponse.split(separator: "\n")
            for line in lines {
                let lineStr = String(line).trimmingCharacters(in: .whitespaces)
                if lineStr.hasPrefix("Title:") {
                    generatedTitle = String(lineStr.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if lineStr.hasPrefix("Preview:") {
                    generatedPreview = String(lineStr.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                }
            }
            
            print("📌 Generated Title: \(generatedTitle)")
            print("👁️ Generated Preview: \(generatedPreview)")
            
            // Second: Generate full summary
            let summaryPrompt = """
            Summarize this content directly. Extract and organize the key information.
            
            Write in this style:
            - State facts directly without commentary
            - Use bullet points for key points
            - Keep all specific details (numbers, dates, names, amounts)
            - Be concise
            - Use **bold** or headers if it helps clarity, but keep it simple
            
            Never write phrases like "This transcript" or "The speaker" or "The document".
            Just write the actual content in organized form.
            
            Content:
            \(transcript)
            
            \(meeting.rawNotes != nil && !meeting.rawNotes!.isEmpty ? "Additional context: \(meeting.rawNotes!)\n" : "")
            """
            
            let summaryConfig = LFM2Manager.ModelConfiguration(
                maxTokens: 1000,  // Good balance for detail
                temperature: 0.3,  // Low for accuracy
                topP: 0.9,
                streamingEnabled: false
            )
            
            print("📝 Generating full summary...")
            let analysisText = try await lfm2Manager.generate(
                prompt: summaryPrompt,
                configuration: summaryConfig
            )
            
            // Print the full analysis for debugging
            print("\n" + String(repeating: "=", count: 50))
            print("📋 MEETING ANALYSIS COMPLETE:")
            print(String(repeating: "-", count: 50))
            print(analysisText)
            print(String(repeating: "=", count: 50) + "\n")
            
            // Save all generated content
            await MainActor.run {
                // Update title if generated
                if !generatedTitle.isEmpty && generatedTitle != "Meeting" {
                    meeting.title = generatedTitle
                }
                
                // Save preview/subtitle
                meeting.subtitle = generatedPreview
                
                // Save full summary
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
                    
                    // Post notification to update UI
                    NotificationCenter.default.post(
                        name: Notification.Name("MeetingAnalysisCompleted"),
                        object: nil,
                        userInfo: ["meetingID": meeting.id]
                    )
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
}