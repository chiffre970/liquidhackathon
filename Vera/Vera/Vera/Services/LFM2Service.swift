import Foundation

@available(iOS 15.0, *)
class LFM2Service {
    private let logger = TelemetryLogger.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let config: LFM2ConfigProtocol
    private let promptManager = PromptManager.shared
    private let leapSDK = LEAPSDKManager.shared
    private let modelQueue = DispatchQueue(label: "com.vera.lfm2.model", qos: .userInitiated)
    
    static let shared: LFM2Service = {
        let config = Environment.current.lfm2Config
        return LFM2Service(config: config)
    }()
    
    init(config: LFM2ConfigProtocol = Environment.current.lfm2Config) {
        self.config = config
        Task {
            await initializeModel()
        }
    }
    
    private func initializeModel() async {
        logger.info("Initializing LFM2 model")
        let startTime = logger.startTimer("Model Initialization")
        
        do {
            try await leapSDK.initialize()
            logger.endTimer("Model Initialization", start: startTime)
            logger.success("LFM2 model initialized successfully")
        } catch {
            logger.error("Failed to initialize LFM2 model: \(error)")
            fatalError("Cannot proceed without LFM2 model: \(error)")
        }
    }
    
    // MARK: - Core Inference
    
    func inference(_ prompt: String, type: String = "general") async throws -> String {
        let inferenceId = performanceMonitor.startInference(type: type)
        let startTime = logger.startTimer("LFM2 Inference - \(type)")
        logger.logMemoryUsage()
        
        var metrics = TelemetryLogger.InferenceMetrics(
            promptType: type,
            inputLength: prompt.count,
            outputLength: 0,
            processingTime: 0,
            memoryUsed: getCurrentMemoryUsage(),
            success: false,
            errorMessage: nil
        )
        
        do {
            logger.info("Starting LFM2 inference for \(type)")
            logger.debug("Prompt preview: \(String(prompt.prefix(100)))...")
            
            // REAL INFERENCE - NO MOCK
            let result = try await leapSDK.generate(
                prompt: prompt,
                maxTokens: config.maxTokens
            )
            
            let endTime = DispatchTime.now()
            let processingTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
            
            metrics = TelemetryLogger.InferenceMetrics(
                promptType: type,
                inputLength: prompt.count,
                outputLength: result.count,
                processingTime: processingTime,
                memoryUsed: getCurrentMemoryUsage(),
                success: true,
                errorMessage: nil
            )
            
            performanceMonitor.endInference(
                id: inferenceId,
                success: true,
                inputSize: prompt.count,
                outputSize: result.count
            )
            
            logger.success("Inference completed for \(type)")
            logger.logInference(metrics)
            logger.endTimer("LFM2 Inference - \(type)", start: startTime)
            
            return result
        } catch {
            metrics = TelemetryLogger.InferenceMetrics(
                promptType: type,
                inputLength: prompt.count,
                outputLength: 0,
                processingTime: 0,
                memoryUsed: getCurrentMemoryUsage(),
                success: false,
                errorMessage: error.localizedDescription
            )
            
            performanceMonitor.endInference(
                id: inferenceId,
                success: false,
                inputSize: prompt.count,
                outputSize: 0,
                error: error.localizedDescription
            )
            
            logger.error("LFM2 inference failed: \(error)")
            logger.logInference(metrics)
            throw error
        }
    }
    
    // MARK: - Batch Processing
    
    func batchInference(_ prompts: [String], type: String = "batch") async throws -> [String] {
        logger.info("Starting batch inference for \(prompts.count) prompts")
        let batchStart = logger.startTimer("Batch Inference")
        
        var results: [String] = []
        var successCount = 0
        var failureCount = 0
        
        // Process in batches based on config
        let batchSize = config.batchSize
        for i in stride(from: 0, to: prompts.count, by: batchSize) {
            let endIndex = min(i + batchSize, prompts.count)
            let batch = Array(prompts[i..<endIndex])
            
            logger.debug("Processing batch \(i/batchSize + 1) (\(batch.count) items)")
            
            // Process batch concurrently
            await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
                for (index, prompt) in batch.enumerated() {
                    group.addTask { [weak self] in
                        do {
                            let result = try await self?.inference(prompt, type: type) ?? ""
                            return (i + index, .success(result))
                        } catch {
                            return (i + index, .failure(error))
                        }
                    }
                }
                
                // Collect results in order
                var batchResults: [(Int, Result<String, Error>)] = []
                for await result in group {
                    batchResults.append(result)
                }
                
                // Sort by index to maintain order
                batchResults.sort { $0.0 < $1.0 }
                
                // Process results
                for (_, result) in batchResults {
                    switch result {
                    case .success(let response):
                        results.append(response)
                        successCount += 1
                    case .failure(let error):
                        results.append("") // Add empty string for failed inference
                        failureCount += 1
                        logger.warning("Batch item failed: \(error)")
                    }
                }
            }
        }
        
        logger.endTimer("Batch Inference", start: batchStart)
        logger.logBatch(
            operation: "inference",
            items: prompts,
            success: successCount,
            failed: failureCount,
            duration: Date().timeIntervalSince(batchStart.uptimeNanoseconds.date)
        )
        
        return results
    }
    
    // MARK: - Specialized Inference Methods
    
    func categorizeTransaction(_ text: String, context: [String] = []) async throws -> String {
        let prompt = promptManager.fillTemplate(
            type: .categoryClassifier,
            variables: [
                "merchant_name": text,
                "amount": extractAmount(from: text),
                "recent_transactions": context.joined(separator: ", ")
            ]
        )
        
        let result = try await inference(prompt, type: "CategoryClassifier")
        
        // Parse and validate the category from response
        let category = extractCategory(from: result)
        guard !category.isEmpty else {
            throw LFM2Error.invalidResponse("Could not extract category from LFM2 response")
        }
        
        return category
    }
    
    func analyzeSpending(_ transactions: [[String: Any]]) async throws -> String {
        let transactionsJSON = try JSONSerialization.data(withJSONObject: transactions)
        let transactionsString = String(data: transactionsJSON, encoding: .utf8) ?? "[]"
        
        let income = calculateIncome(from: transactions)
        let expenses = calculateExpenses(from: transactions)
        
        let prompt = promptManager.fillTemplate(
            type: .insightsAnalyzer,
            variables: [
                "transactions_json": transactionsString,
                "income": income,
                "expenses": expenses
            ]
        )
        
        return try await inference(prompt, type: "InsightsAnalyzer")
    }
    
    func negotiateBudget(
        currentSpending: [String: Double],
        userMessage: String,
        chatHistory: [String] = []
    ) async throws -> String {
        let spendingJSON = try JSONSerialization.data(withJSONObject: currentSpending)
        let spendingString = String(data: spendingJSON, encoding: .utf8) ?? "{}"
        
        let prompt = promptManager.fillTemplate(
            type: .budgetNegotiator,
            variables: [
                "current_spending": spendingString,
                "user_message": userMessage,
                "chat_history": chatHistory.joined(separator: "\n")
            ]
        )
        
        return try await inference(prompt, type: "BudgetNegotiator")
    }
    
    // MARK: - Helper Methods
    
    private func extractCategory(from response: String) -> String {
        // Categories we expect from the model
        let validCategories = ["Housing", "Food", "Transportation", "Healthcare", 
                              "Entertainment", "Shopping", "Savings", "Utilities", 
                              "Income", "Other"]
        
        // Try to find a valid category in the response
        for category in validCategories {
            if response.contains(category) {
                return category
            }
        }
        
        // If response is just the category name
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if validCategories.contains(trimmed) {
            return trimmed
        }
        
        return ""
    }
    
    private func extractAmount(from text: String) -> String {
        // Simple regex to extract dollar amounts
        let pattern = #"\$?[\d,]+\.?\d*"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            return String(text[Range(match.range, in: text)!])
        }
        return "0"
    }
    
    private func calculateIncome(from transactions: [[String: Any]]) -> String {
        let income = transactions
            .compactMap { $0["amount"] as? Double }
            .filter { $0 > 0 }
            .reduce(0, +)
        return String(format: "%.2f", income)
    }
    
    private func calculateExpenses(from transactions: [[String: Any]]) -> String {
        let expenses = transactions
            .compactMap { $0["amount"] as? Double }
            .filter { $0 < 0 }
            .map { abs($0) }
            .reduce(0, +)
        return String(format: "%.2f", expenses)
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        
        return 0
    }
}

// MARK: - Error Types

enum LFM2Error: LocalizedError {
    case modelNotLoaded
    case inferenceTimeout
    case invalidPrompt
    case invalidResponse(String)
    case memoryLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "LFM2 model is not loaded"
        case .inferenceTimeout:
            return "Inference operation timed out"
        case .invalidPrompt:
            return "Invalid prompt provided"
        case .invalidResponse(let details):
            return "Invalid LFM2 response: \(details)"
        case .memoryLimitExceeded:
            return "Memory limit exceeded"
        }
    }
}

// MARK: - Date Extension

private extension UInt64 {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(self) / 1_000_000_000)
    }
}