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
            if let prompt = loadPromptFromFile(promptType.fileName) {
                prompts[promptType.rawValue] = prompt
            }
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
            if let cached = prompts[type.rawValue] {
                return cached
            }
            
            // Try loading from file if not cached
            if let prompt = loadPromptFromFile(type.fileName) {
                prompts[type.rawValue] = prompt
                return prompt
            }
            
            // Return fallback prompt
            return getFallbackPrompt(for: type)
        }
    }
    
    func loadPrompt(_ name: String) -> String {
        return promptQueue.sync {
            if let cached = prompts[name] {
                return cached
            }
            
            // Try loading from file if not cached
            if let prompt = loadPromptFromFile("\(name).prompt") {
                prompts[name] = prompt
                return prompt
            }
            
            // Try to find by PromptType
            if let type = PromptType(rawValue: name) {
                return getFallbackPrompt(for: type)
            }
            
            return "Process the following input: {input}"
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
    
    private func getFallbackPrompt(for type: PromptType) -> String {
        switch type {
        case .transactionParser:
            return """
            Parse the transaction: {raw_transaction}
            Extract merchant, amount, date, and type.
            """
        case .categoryClassifier:
            return """
            Categorize this transaction: {merchant_name} - ${amount}
            Choose from: Housing, Food, Transportation, Healthcare, Entertainment, Shopping, Savings, Utilities, Income, Other
            """
        case .insightsAnalyzer:
            return """
            Analyze these transactions: {transactions_json}
            Provide spending insights and recommendations.
            """
        case .budgetNegotiator:
            return """
            Help create a budget based on: {current_spending}
            User says: {user_message}
            """
        case .budgetInsights:
            return """
            Compare budget {budget_allocations} vs actual {actual_spending}
            Provide optimization insights.
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