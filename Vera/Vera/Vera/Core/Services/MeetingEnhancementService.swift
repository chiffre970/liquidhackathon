import Foundation
import CoreData

// Simple text-based enhancement for hackathon
// No complex JSON parsing or structured data - just plain text analysis

class MeetingEnhancementService {
    static let shared = MeetingEnhancementService()
    private let lfm2Manager = LFM2Manager.shared
    private let promptService = AdaptivePromptService.shared
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
            
            // Step 1: Analyze what elements would be helpful to extract
            let analysisPrompt = promptService.generateAnalysisPrompt(
                transcript: transcript,
                userNotes: meeting.rawNotes
            )
            
            let config = LFM2Manager.ModelConfiguration(
                maxTokens: 200,  // Short response for element list
                temperature: 0.3,  // Lower temperature for more consistent analysis
                topP: 0.9,
                streamingEnabled: false
            )
            
            print("📊 Step 1: Analyzing content to determine relevant elements...")
            let elementsResponse = try await lfm2Manager.generate(
                prompt: analysisPrompt,
                configuration: config
            )
            
            // Parse which elements to extract
            let elementsToExtract = promptService.parseElementsToExtract(from: elementsResponse)
            print("   Elements to extract: \(elementsToExtract.map { $0.rawValue }.joined(separator: ", "))")
            
            // Step 2: Extract only the identified elements
            let extractionPrompt = promptService.generateExtractionPrompt(
                transcript: transcript,
                userNotes: meeting.rawNotes,
                elementsToExtract: elementsToExtract
            )
            
            let extractionConfig = LFM2Manager.ModelConfiguration(
                maxTokens: 1000,
                temperature: 0.5,  // Balanced temperature for extraction
                topP: 0.9,
                streamingEnabled: false
            )
            
            print("📝 Step 2: Extracting relevant content...")
            let analysisText = try await lfm2Manager.generate(
                prompt: extractionPrompt,
                configuration: extractionConfig
            )
            
            // Save the analysis as enhanced notes
            await MainActor.run {
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