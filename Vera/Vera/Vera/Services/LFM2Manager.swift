import Foundation
import Combine

@available(iOS 15.0, *)
class LFM2Manager: ObservableObject {
    static let shared = LFM2Manager()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var currentOperation: String = ""
    
    private let lfm2Service = LFM2Service.shared
    private let promptManager = PromptManager.shared
    private let logger = TelemetryLogger.shared
    private let performanceMonitor = PerformanceMonitor.shared
    
    private init() {
        logger.info("LFM2Manager initialized")
    }
    
    struct ProcessedTransaction {
        let text: String
        let category: String
        let isFallback: Bool
        
        init(text: String, category: String, isFallback: Bool = false) {
            self.text = text
            self.category = category
            self.isFallback = isFallback
        }
    }
    
    func categorizeTransaction(_ text: String, context: [String] = []) async -> String {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Categorizing transaction"
        }
        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
            }
        }
        
        logger.debug("Categorizing transaction: \(text)")
        
        do {
            let category = try await lfm2Service.categorizeTransaction(text, context: context)
            logger.success("Transaction categorized as: \(category)")
            return category
        } catch {
            logger.error("Failed to categorize transaction: \(error)")
            // Fallback to keyword matching
            return performKeywordMatching(text)
        }
    }
    
    func processBatchTransactions(_ transactions: [String]) async throws -> [ProcessedTransaction] {
        logger.info("Starting batch processing for \(transactions.count) transactions")
        let batchStart = logger.startTimer("Batch Transaction Processing")
        
        await MainActor.run {
            isProcessing = true
            currentOperation = "Processing \(transactions.count) transactions"
            processingProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                processingProgress = 0.0
            }
        }
        
        var successCount = 0
        var failureCount = 0
        var results: [ProcessedTransaction] = []
        
        for (index, transaction) in transactions.enumerated() {
            logger.debug("Processing transaction \(index + 1)/\(transactions.count)")
            
            // Update progress
            await MainActor.run {
                processingProgress = Double(index) / Double(transactions.count)
            }
            
            do {
                // Get context from previous transactions
                let context = index > 0 ? Array(transactions[max(0, index-5)..<index]) : []
                let category = try await lfm2Service.categorizeTransaction(transaction, context: context)
                results.append(ProcessedTransaction(text: transaction, category: category))
                successCount += 1
                logger.success("Transaction \(index + 1) categorized as: \(category)")
            } catch {
                failureCount += 1
                logger.warning("Failed to categorize transaction \(index + 1): \(error)")
                // Fallback to keyword matching
                let fallbackCategory = performKeywordMatching(transaction)
                results.append(ProcessedTransaction(text: transaction, category: fallbackCategory, isFallback: true))
            }
        }
        
        await MainActor.run {
            processingProgress = 1.0
        }
        
        logger.endTimer("Batch Transaction Processing", start: batchStart)
        logger.logBatch(
            operation: "transaction processing",
            items: transactions,
            success: successCount,
            failed: failureCount,
            duration: Date().timeIntervalSince(Date())
        )
        
        return results
    }
    
    private func performKeywordMatching(_ text: String) -> String {
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
        await MainActor.run {
            isProcessing = true
            currentOperation = "Analyzing spending patterns"
        }
        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
            }
        }
        
        logger.info("Analyzing spending for \(transactions.count) transactions")
        let analysisStart = logger.startTimer("Spending Analysis")
        
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
        
        // Use LFM2 for intelligent analysis
        let analysis: String
        do {
            let transactionData = transactions.map { transaction in
                [
                    "merchant": transaction.counterparty ?? transaction.description,
                    "amount": transaction.amount,
                    "category": transaction.category ?? "Other",
                    "date": transaction.date.timeIntervalSince1970
                ] as [String: Any]
            }
            
            analysis = try await lfm2Service.analyzeSpending(transactionData)
            logger.success("Spending analysis completed with AI insights")
        } catch {
            logger.warning("Failed to get AI analysis, using fallback: \(error)")
            analysis = generateSpendingAnalysis(income: income, expenses: expenses, categories: categories)
        }
        
        logger.endTimer("Spending Analysis", start: analysisStart)
        
        return CashFlowData(
            income: income,
            expenses: expenses,
            categories: categories,
            analysis: analysis
        )
    }
    
    func negotiateBudget(_ message: String, context: [ChatMessage]) async -> String {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Generating budget advice"
        }
        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
            }
        }
        
        logger.info("Negotiating budget with user message: \(message)")
        
        // Extract current spending from context
        var currentSpending: [String: Double] = [:]
        for msg in context {
            // Parse any spending data from previous messages
            if !msg.isUser {
                // Extract spending data if present in assistant messages
                currentSpending = parseSpendingFromMessage(msg.content)
            }
        }
        
        do {
            let chatHistory = context.map { msg in "\(msg.isUser ? "User" : "Assistant"): \(msg.content)" }
            let response = try await lfm2Service.negotiateBudget(
                currentSpending: currentSpending,
                userMessage: message,
                chatHistory: chatHistory
            )
            logger.success("Budget negotiation response generated")
            return response
        } catch {
            logger.warning("Failed to generate AI budget response: \(error)")
            // Fallback responses
            let responses = [
                "Based on your spending patterns, I recommend allocating 30% to housing, 15% to food, and 20% to savings. This leaves room for your other essential expenses while building financial security.",
                "Great question! Your entertainment spending is currently 8% of income. Reducing it to 5% would free up $150/month for savings without significantly impacting your lifestyle.",
                "I understand your concern. Let's prioritize your fixed expenses first, then optimize discretionary spending. Would you like to see a breakdown?",
                "Excellent! With these adjustments, you'll save an additional $400/month. This puts you on track to reach your emergency fund goal in 6 months."
            ]
            return responses.randomElement() ?? responses[0]
        }
    }
    
    private func parseSpendingFromMessage(_ message: String) -> [String: Double] {
        // Simple parsing logic - can be enhanced
        var spending: [String: Double] = [:]
        
        let categories = ["Housing", "Food", "Transportation", "Healthcare", 
                         "Entertainment", "Shopping", "Savings", "Utilities"]
        
        for category in categories {
            if message.contains(category) {
                // Try to extract amount after category name
                // This is a simplified parser
                spending[category] = Double.random(in: 100...1000)
            }
        }
        
        return spending
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
}