import Foundation

class PromptManager {
    static let shared = PromptManager()
    private var prompts: [String: String] = [:]
    private let promptQueue = DispatchQueue(label: "com.vera.promptmanager", attributes: .concurrent)
    
    private init() {
        preloadPrompts()
    }
    
    enum PromptType: String, CaseIterable {
        case transactionParser = "TransactionParser"
        case categoryClassifier = "CategoryClassifier"
        case insightsAnalyzer = "InsightsAnalyzer"
        case budgetNegotiator = "BudgetNegotiator"
        case budgetInsights = "BudgetInsights"
        
        var fileName: String {
            return "\(rawValue).prompt"
        }
    }
    
    private func preloadPrompts() {
        for promptType in PromptType.allCases {
            guard let prompt = loadPromptFromFile(promptType.fileName) else {
                fatalError("Required prompt file missing: \(promptType.fileName)")
            }
            prompts[promptType.rawValue] = prompt
        }
    }
    
    private func loadPromptFromFile(_ fileName: String) -> String? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Prompts") else {
            print("Warning: Could not find prompt file: \(fileName)")
            return nil
        }
        
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            print("Error loading prompt file \(fileName): \(error)")
            return nil
        }
    }
    
    func loadPrompt(_ type: PromptType) -> String {
        return promptQueue.sync {
            guard let prompt = prompts[type.rawValue] else {
                fatalError("Prompt not loaded: \(type.rawValue)")
            }
            return prompt
        }
    }
    
    func loadPrompt(_ name: String) -> String {
        return promptQueue.sync {
            guard let prompt = prompts[name] else {
                fatalError("Prompt not loaded: \(name)")
            }
            return prompt
        }
    }
    
    func fillTemplate(_ prompt: String, variables: [String: Any]) -> String {
        var filledPrompt = prompt
        
        for (key, value) in variables {
            let placeholder = "{\(key)}"
            let replacement = String(describing: value)
            filledPrompt = filledPrompt.replacingOccurrences(of: placeholder, with: replacement)
        }
        
        return filledPrompt
    }
    
    func fillTemplate(type: PromptType, variables: [String: Any]) -> String {
        let prompt = loadPrompt(type)
        return fillTemplate(prompt, variables: variables)
    }
    
    
    func reloadPrompts() {
        promptQueue.async(flags: .barrier) {
            self.prompts.removeAll()
            self.preloadPrompts()
        }
    }
}