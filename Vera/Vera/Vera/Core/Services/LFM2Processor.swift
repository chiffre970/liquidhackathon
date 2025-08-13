import Foundation

struct ProcessedThought {
    let summary: String
    let category: Category
    let tags: [String]
}

class LFM2Processor {
    static let shared = LFM2Processor()
    private let lfm2Manager = LFM2Manager.shared
    
    private init() {}
    
    func processThought(transcription: String) async -> ProcessedThought {
        let prompt = """
        Analyze this transcribed thought and categorize it:
        "\(transcription)"
        
        Determine if this is:
        1. ACTION - Something the user wants to do
        2. THOUGHT - An idea, observation, or reflection
        
        Response format:
        {
          "category": "ACTION" or "THOUGHT",
          "summary": "One sentence summary",
          "tags": ["relevant", "tags"],
          "priority": "high/medium/low" (for actions only),
          "deadline_hint": "any mentioned timeframe" (for actions only),
          "theme": "main theme" (for thoughts only)
        }
        """
        
        let response = await lfm2Manager.process(prompt: prompt)
        return parseResponse(response, transcription: transcription)
    }
    
    func summarizeSession(thoughts: [Thought]) async -> String {
        let thoughtsData = thoughts.map { thought in
            [
                "transcription": thought.rawTranscription,
                "summary": thought.summary,
                "category": thought.category?.displayName ?? "Unknown"
            ]
        }
        
        let prompt = """
        Summarize this recording session's thoughts:
        \(thoughtsData)
        
        Create a brief overview highlighting:
        - Key themes
        - Important actions identified
        - Notable insights
        
        Keep it under 3 sentences.
        """
        
        return await lfm2Manager.process(prompt: prompt)
    }
    
    private func parseResponse(_ response: String, transcription: String) -> ProcessedThought {
        do {
            guard let data = response.data(using: .utf8) else {
                return createDefaultThought(from: transcription)
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            let categoryType = json?["category"] as? String ?? "THOUGHT"
            let summary = json?["summary"] as? String ?? extractSummary(from: transcription)
            let tags = json?["tags"] as? [String] ?? []
            
            let category: Category
            if categoryType == "ACTION" {
                let priorityStr = json?["priority"] as? String ?? "medium"
                let priority = Category.Priority(rawValue: priorityStr) ?? .medium
                
                let deadline: Date? = nil
                
                category = .action(deadline: deadline, priority: priority)
            } else {
                let theme = json?["theme"] as? String ?? "general"
                category = .thought(theme: theme)
            }
            
            return ProcessedThought(
                summary: summary,
                category: category,
                tags: tags
            )
            
        } catch {
            return createDefaultThought(from: transcription)
        }
    }
    
    private func createDefaultThought(from transcription: String) -> ProcessedThought {
        return ProcessedThought(
            summary: extractSummary(from: transcription),
            category: .thought(theme: "general"),
            tags: []
        )
    }
    
    private func extractSummary(from text: String) -> String {
        let words = text.split(separator: " ")
        if words.count <= 15 {
            return text
        }
        return words.prefix(15).joined(separator: " ") + "..."
    }
}