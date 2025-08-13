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
        case transactionDeduplicator = "TransactionDeduplicator"
        case budgetChat = "BudgetChat"
        
        var fileName: String {
            return "\(rawValue).prompt"
        }
    }
    
    private func preloadPrompts() {
        for promptType in PromptType.allCases {
            if let prompt = loadPromptFromFile(promptType.fileName) {
                prompts[promptType.rawValue] = prompt
            } else {
                print("Warning: Using default prompt for \(promptType.rawValue)")
                prompts[promptType.rawValue] = getDefaultPrompt(for: promptType)
            }
        }
    }
    
    private func loadPromptFromFile(_ fileName: String) -> String? {
        // Try with subdirectory first
        if let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Prompts") {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        
        // Try without subdirectory (files might be in root)
        let fileNameWithoutExtension = fileName.replacingOccurrences(of: ".prompt", with: "")
        if let url = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "prompt") {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        
        print("Warning: Could not find prompt file: \(fileName)")
        return nil
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
    
    private func getDefaultPrompt(for type: PromptType) -> String {
        switch type {
        case .transactionParser:
            return "Parse the following transaction: {{transaction_text}}"
        case .categoryClassifier:
            return "Classify this transaction into a category: {{description}}"
        case .insightsAnalyzer:
            return "Analyze these transactions and provide insights: {{transactions_json}}"
        case .budgetNegotiator:
            return "Help create a budget based on: {{spending_json}}"
        case .budgetInsights:
            return "Provide budget insights for: {{budget_data}}"
        case .transactionDeduplicator:
            return "Find duplicate transactions in: {{transactions}}"
        case .budgetChat:
            return """
            You are a personal finance advisor helping users manage their budget. Analyze their spending and provide specific, actionable advice.
            
            Current spending breakdown:
            {spending_data}
            
            Previous conversation:
            {conversation_history}
            
            User message: {user_message}
            
            Provide a helpful response that:
            1. Addresses the user's question directly
            2. Points out any concerning spending patterns with specific amounts
            3. Suggests 2-3 practical ways to improve their budget
            
            Be conversational but honest about problem areas. Focus on the highest impact changes they could make.
            
            Response:
            """
        }
    }
    
    
    func reloadPrompts() {
        promptQueue.async(flags: .barrier) {
            self.prompts.removeAll()
            self.preloadPrompts()
        }
    }
}