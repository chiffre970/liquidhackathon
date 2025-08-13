import Foundation
import Combine

@available(iOS 15.0, *)
class LFM2Manager: ObservableObject {
    static let shared = LFM2Manager()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var currentOperation: String = ""
    @Published var isModelInitialized = false
    
    private let lfm2Service = LFM2Service.shared
    private let promptManager = PromptManager.shared
    private let logger = TelemetryLogger.shared
    private let performanceMonitor = PerformanceMonitor.shared
    
    private init() {
        logger.info("LFM2Manager initialized")
    }
    
    func initialize() async {
        // Initialize the LFM2 service and LEAP SDK
        logger.info("Initializing LFM2 service...")
        await lfm2Service.initialize()
        
        // Update the published property on main thread
        await MainActor.run {
            self.isModelInitialized = lfm2Service.isModelLoaded()
        }
        
        logger.success("LFM2 service initialized: \(lfm2Service.isModelLoaded())")
    }
    
    struct ProcessedTransaction {
        let text: String
        let category: String
        
        init(text: String, category: String) {
            self.text = text
            self.category = category
        }
    }
    
    func categorizeTransaction(_ text: String, context: [String] = []) async throws -> String {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.currentOperation = "Categorizing transaction"
        }
        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentOperation = ""
            }
        }
        
        logger.debug("Categorizing transaction: \(text)")
        
        let category = try await lfm2Service.categorizeTransaction(text, context: context)
        logger.success("Transaction categorized as: \(category)")
        return category
    }
    
    func processBatchTransactions(_ transactions: [String]) async throws -> [ProcessedTransaction] {
        logger.info("Starting batch processing for \(transactions.count) transactions")
        let batchStart = logger.startTimer("Batch Transaction Processing")
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.currentOperation = "Processing \(transactions.count) transactions"
            self.processingProgress = 0.0
        }
        
        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentOperation = ""
                self.processingProgress = 0.0
            }
        }
        
        var successCount = 0
        var failureCount = 0
        var results: [ProcessedTransaction] = []
        
        for (index, transaction) in transactions.enumerated() {
            logger.debug("Processing transaction \(index + 1)/\(transactions.count)")
            
            // Update progress
            DispatchQueue.main.async {
                self.processingProgress = Double(index) / Double(transactions.count)
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
                logger.error("Failed to categorize transaction \(index + 1): \(error)")
                throw error // Stop processing on error instead of fallback
            }
        }
        
        DispatchQueue.main.async {
            self.processingProgress = 1.0
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
    
    
    func analyzeSpending(_ transactions: [Transaction]) async throws -> CashFlowData {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.currentOperation = "Analyzing spending patterns"
        }
        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentOperation = ""
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
        let transactionData = transactions.map { transaction in
            [
                "merchant": transaction.counterparty ?? transaction.description,
                "amount": transaction.amount,
                "category": transaction.category ?? "Other",
                "date": transaction.date.timeIntervalSince1970
            ] as [String: Any]
        }
        
        let analysis = try await lfm2Service.analyzeSpending(transactionData)
        logger.success("Spending analysis completed with AI insights")
        
        logger.endTimer("Spending Analysis", start: analysisStart)
        
        return CashFlowData(
            income: income,
            expenses: expenses,
            categories: categories,
            analysis: analysis
        )
    }
    
    func negotiateBudget(_ message: String, context: [ChatMessage]) async throws -> String {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.currentOperation = "Generating budget advice"
        }
        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentOperation = ""
            }
        }
        
        logger.info("Negotiating budget with user message: \(message)")
        
        // Extract current spending from context
        var currentSpending: [String: Double] = [:]
        for msg in context {
            // Parse any spending data from previous messages
            if !msg.isUser {
                // Extract spending data if present in assistant messages
                currentSpending = extractSpendingFromMessage(msg.content)
            }
        }
        
        let chatHistory = context.map { msg in "\(msg.isUser ? "User" : "Assistant"): \(msg.content)" }
        let response = try await lfm2Service.negotiateBudget(
            currentSpending: currentSpending,
            userMessage: message,
            chatHistory: chatHistory
        )
        logger.success("Budget negotiation response generated")
        return response
    }
    
    private func extractSpendingFromMessage(_ message: String) -> [String: Double] {
        // Extract actual spending amounts from message if present
        var spending: [String: Double] = [:]
        
        let categories = ["Housing", "Food", "Transportation", "Healthcare", 
                         "Entertainment", "Shopping", "Savings", "Utilities"]
        
        for category in categories {
            if message.contains(category) {
                // Try to extract actual amount using regex
                let pattern = "\(category)[^0-9]*([0-9,]+\\.?[0-9]*)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    if let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) {
                        if let amountRange = Range(match.range(at: 1), in: message) {
                            let amountStr = String(message[amountRange]).replacingOccurrences(of: ",", with: "")
                            if let amount = Double(amountStr) {
                                spending[category] = amount
                            }
                        }
                    }
                }
            }
        }
        
        return spending
    }
}