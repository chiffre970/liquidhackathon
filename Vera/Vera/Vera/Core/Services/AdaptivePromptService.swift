import Foundation

class AdaptivePromptService {
    static let shared = AdaptivePromptService()
    
    private init() {}
    
    enum ExtractionElement: String, CaseIterable {
        case actionItems = "Action items"
        case decisions = "Decisions"
        case ideas = "Ideas"
        case questions = "Questions"
        case keyPoints = "Key points"
        case peopleDates = "People & dates"
        
        var description: String {
            switch self {
            case .actionItems: return "Tasks, next steps, todos, things that need to be done"
            case .decisions: return "What was decided, concluded, or agreed upon"
            case .ideas: return "Concepts, suggestions, possibilities, creative thoughts"
            case .questions: return "Open issues, unknowns, things to explore or figure out"
            case .keyPoints: return "Important information, facts, main takeaways, critical details"
            case .peopleDates: return "Who's responsible for what, when things are happening, deadlines"
            }
        }
    }
    
    // Step 1: Analyze what would be helpful to extract
    func generateAnalysisPrompt(transcript: String, userNotes: String?) -> String {
        let elements = ExtractionElement.allCases.map { "- \($0.rawValue): \($0.description)" }.joined(separator: "\n")
        
        return """
        Analyze this transcript and determine which elements would be most helpful to extract and summarize.
        
        Transcript:
        \(transcript)
        
        \(userNotes != nil && !userNotes!.isEmpty ? "User Notes: \(userNotes!)\n" : "")
        
        From the following list, identify which elements would actually be valuable for this content:
        \(elements)
        
        Return ONLY the relevant element names as a comma-separated list.
        For example: "Action items, Decisions, People & dates"
        
        Only include elements that are genuinely present and useful. Don't force categories that don't apply.
        """
    }
    
    // Step 2: Extract only the identified elements
    func generateExtractionPrompt(
        transcript: String,
        userNotes: String?,
        elementsToExtract: [ExtractionElement]
    ) -> String {
        let elementsList = elementsToExtract.map { "- \($0.rawValue)" }.joined(separator: "\n")
        
        return """
        Based on this transcript, extract and summarize ONLY the following elements:
        \(elementsList)
        
        Transcript:
        \(transcript)
        
        \(userNotes != nil && !userNotes!.isEmpty ? "User Notes: \(userNotes!)\n" : "")
        
        For each element you extract:
        - Use the element name as a clear section header
        - Be concise but complete
        - Use bullet points for multiple items
        - Only include sections for elements that actually have content
        
        If an element has no relevant content, skip it entirely.
        Focus on being helpful and actionable.
        """
    }
    
    // Parse the response from Step 1 to get elements to extract
    func parseElementsToExtract(from response: String) -> [ExtractionElement] {
        let normalized = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var elements: [ExtractionElement] = []
        
        for element in ExtractionElement.allCases {
            if normalized.contains(element.rawValue.lowercased()) {
                elements.append(element)
            }
        }
        
        // If nothing was detected or parsing failed, provide sensible defaults
        if elements.isEmpty {
            return [.keyPoints] // At minimum, extract key points
        }
        
        return elements
    }
}