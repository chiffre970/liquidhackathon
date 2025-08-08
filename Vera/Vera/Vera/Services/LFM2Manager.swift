import Foundation
import Combine

class LFM2Manager: ObservableObject {
    static let shared = LFM2Manager()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    
    private init() {}
    
    func categorizeTransaction(_ text: String) async -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        let categories = ["Housing", "Food", "Transportation", "Healthcare", 
                         "Entertainment", "Shopping", "Savings", "Utilities", "Other"]
        
        await simulateProcessing()
        
        let lowercased = text.lowercased()
        
        if lowercased.contains("rent") || lowercased.contains("mortgage") || lowercased.contains("housing") {
            return "Housing"
        } else if lowercased.contains("grocery") || lowercased.contains("restaurant") || lowercased.contains("food") || lowercased.contains("dining") {
            return "Food"
        } else if lowercased.contains("uber") || lowercased.contains("lyft") || lowercased.contains("gas") || lowercased.contains("transport") {
            return "Transportation"
        } else if lowercased.contains("doctor") || lowercased.contains("pharmacy") || lowercased.contains("medical") || lowercased.contains("health") {
            return "Healthcare"
        } else if lowercased.contains("movie") || lowercased.contains("netflix") || lowercased.contains("spotify") || lowercased.contains("entertainment") {
            return "Entertainment"
        } else if lowercased.contains("amazon") || lowercased.contains("store") || lowercased.contains("shopping") || lowercased.contains("retail") {
            return "Shopping"
        } else if lowercased.contains("savings") || lowercased.contains("investment") || lowercased.contains("deposit") {
            return "Savings"
        } else if lowercased.contains("electric") || lowercased.contains("water") || lowercased.contains("utility") || lowercased.contains("internet") {
            return "Utilities"
        } else {
            return "Other"
        }
    }
    
    func analyzeSpending(_ transactions: [Transaction]) async -> CashFlowData {
        isProcessing = true
        defer { isProcessing = false }
        
        await simulateProcessing()
        
        let income = transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expenses = abs(transactions.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount })
        
        var categoryTotals: [String: Double] = [:]
        
        for transaction in transactions.filter({ $0.amount < 0 }) {
            let category = transaction.category ?? "Other"
            categoryTotals[category, default: 0] += abs(transaction.amount)
        }
        
        let categories = categoryTotals.map { key, value in
            CashFlowData.Category(
                name: key,
                amount: value,
                percentage: expenses > 0 ? (value / expenses) * 100 : 0
            )
        }.sorted { $0.amount > $1.amount }
        
        let analysis = generateSpendingAnalysis(income: income, expenses: expenses, categories: categories)
        
        return CashFlowData(
            income: income,
            expenses: expenses,
            categories: categories,
            analysis: analysis
        )
    }
    
    func negotiateBudget(_ message: String, context: [ChatMessage]) async -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        await simulateProcessing()
        
        let responses = [
            "Based on your spending patterns, I recommend allocating 30% to housing, 15% to food, and 20% to savings. This leaves room for your other essential expenses while building financial security.",
            "Great question! Your entertainment spending is currently 8% of income. Reducing it to 5% would free up $150/month for savings without significantly impacting your lifestyle.",
            "I understand your concern. Let's prioritize your fixed expenses first, then optimize discretionary spending. Would you like to see a breakdown?",
            "Excellent! With these adjustments, you'll save an additional $400/month. This puts you on track to reach your emergency fund goal in 6 months."
        ]
        
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateSpendingAnalysis(income: Double, expenses: Double, categories: [CashFlowData.Category]) -> String {
        let savingsRate = income > 0 ? ((income - expenses) / income) * 100 : 0
        let topCategory = categories.first
        
        var analysis = "Your financial overview: "
        
        if savingsRate > 20 {
            analysis += "Excellent savings rate of \(Int(savingsRate))%! "
        } else if savingsRate > 10 {
            analysis += "Good savings rate of \(Int(savingsRate))%. "
        } else {
            analysis += "Savings rate of \(Int(savingsRate))% could be improved. "
        }
        
        if let topCategory = topCategory {
            analysis += "\(topCategory.name) is your largest expense at \(Int(topCategory.percentage))% of spending. "
        }
        
        if savingsRate < 20 {
            analysis += "Consider reviewing discretionary spending in Entertainment and Shopping categories for optimization opportunities."
        } else {
            analysis += "You're on track with your financial goals. Keep maintaining this balanced approach!"
        }
        
        return analysis
    }
    
    private func simulateProcessing() async {
        for i in 0...10 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await MainActor.run {
                processingProgress = Double(i) / 10.0
            }
        }
    }
}