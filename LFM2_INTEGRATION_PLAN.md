# LFM2 Integration Plan for Vera App

## Overview
This document outlines the plan for integrating the Liquid Foundation Model 2 (LFM2) into the Vera iOS app for local, privacy-first financial analysis.

## 1. Hyperparameterization Architecture

### 1.1 Configuration Structure
Create a centralized configuration system for all LFM2 parameters:

```swift
// Config/LFM2Config.swift
struct LFM2Config {
    // Model Configuration
    static let modelName = "lfm2-700m"
    static let modelPath = Bundle.main.path(forResource: "lfm2-700m", ofType: "mlmodel")
    static let maxTokens = 512
    static let temperature = 0.7
    static let topP = 0.9
    static let topK = 40
    
    // Processing Configuration
    static let batchSize = 10
    static let maxConcurrentTasks = 3
    static let timeoutSeconds = 30
    static let cacheEnabled = true
    static let cacheExpirationHours = 24
    
    // Memory Management
    static let maxMemoryMB = 2048
    static let lowMemoryThreshold = 0.8
    
    // Feature Flags
    static let useStreamingInference = false
    static let enableDebugLogging = false
    static let fallbackToKeywordMatching = true
}
```

### 1.2 Environment-based Configuration
```swift
// Config/Environment.swift
enum Environment {
    case development
    case staging
    case production
    
    var lfm2Config: LFM2ConfigProtocol {
        switch self {
        case .development:
            return LFM2ConfigDev()
        case .staging:
            return LFM2ConfigStaging()
        case .production:
            return LFM2ConfigProd()
        }
    }
}
```

## 2. System Prompts Architecture

### 2.1 Prompt Files Structure
```
Vera/
├── Prompts/
│   ├── TransactionParser.prompt
│   ├── CategoryClassifier.prompt
│   ├── InsightsAnalyzer.prompt
│   ├── BudgetNegotiator.prompt
│   └── BudgetInsights.prompt
```

### 2.2 Prompt Templates

#### TransactionParser.prompt
```
You are a financial transaction parser. Extract the following from raw transaction text:
- Merchant name
- Amount
- Date
- Transaction type (debit/credit)

Input: {raw_transaction}
Output format: JSON
{
  "merchant": string,
  "amount": number,
  "date": "YYYY-MM-DD",
  "type": "debit" | "credit"
}
```

#### CategoryClassifier.prompt
```
Classify this financial transaction into ONE category.
Categories: Housing, Food, Transportation, Healthcare, Entertainment, Shopping, Savings, Utilities, Income, Other

Transaction: {merchant_name} - ${amount}
Previous transactions context: {recent_transactions}

Output only the category name.
```

#### InsightsAnalyzer.prompt
```
Analyze these monthly transactions and provide insights:
Transactions: {transactions_json}
Total income: ${income}
Total expenses: ${expenses}

Provide:
1. Spending pattern analysis
2. Top 3 concerning trends
3. Top 3 positive behaviors
4. Actionable recommendations

Keep response under 200 words, be specific with percentages and amounts.
```

#### BudgetNegotiator.prompt
```
You are a helpful financial advisor helping create a realistic budget.
Current spending: {current_spending}
User message: {user_message}
Conversation history: {chat_history}

Respond conversationally, suggest specific percentage allocations, and be encouraging but realistic.
Max 150 words.
```

#### BudgetInsights.prompt
```
Generate budget optimization insights based on:
Current budget: {budget_allocations}
Actual spending: {actual_spending}
Savings goal: ${savings_target}

Provide:
1. Budget adherence score (0-100)
2. Top overspending categories
3. Optimization opportunities
4. Projected savings timeline

Format as structured insights, use specific numbers.
```

### 2.3 Prompt Manager
```swift
// Services/PromptManager.swift
class PromptManager {
    static let shared = PromptManager()
    private var prompts: [String: String] = [:]
    
    func loadPrompt(_ name: String) -> String {
        // Cache and return prompt from file
    }
    
    func fillTemplate(_ prompt: String, variables: [String: Any]) -> String {
        // Replace {variables} in prompt
    }
}
```

## 3. LFM2 Integration Implementation

### 3.1 Core LFM2 Service
```swift
// Services/LFM2Service.swift
class LFM2Service {
    private let leapSDK: LEAPKit
    private let config: LFM2Config
    private let promptManager: PromptManager
    
    // Initialize with LEAP SDK
    init() async throws {
        self.leapSDK = try await LEAPKit.initialize(
            modelPath: LFM2Config.modelPath,
            config: LEAPConfig(
                maxTokens: LFM2Config.maxTokens,
                temperature: LFM2Config.temperature
            )
        )
    }
    
    // Core inference method
    func inference(_ prompt: String) async throws -> String {
        return try await leapSDK.generate(prompt: prompt)
    }
}
```

### 3.2 Updated LFM2Manager
```swift
// Services/LFM2Manager.swift
class LFM2Manager: ObservableObject {
    private let lfm2Service: LFM2Service
    private let promptManager: PromptManager
    
    func categorizeTransaction(_ text: String) async throws -> String {
        let prompt = promptManager.loadPrompt("CategoryClassifier")
        let filled = promptManager.fillTemplate(prompt, variables: [
            "merchant_name": text,
            "amount": extractAmount(text)
        ])
        
        return try await lfm2Service.inference(filled)
    }
    
    func analyzeSpending(_ transactions: [Transaction]) async throws -> CashFlowData {
        let prompt = promptManager.loadPrompt("InsightsAnalyzer")
        // ... prepare and execute
    }
}
```

## 4. Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Set up LEAP SDK Swift Package dependency
- [ ] Create configuration management system
- [ ] Implement prompt file loading system
- [ ] Create PromptManager class
- [ ] Set up error handling and fallback mechanisms

### Phase 2: Model Integration (Week 1-2)
- [ ] Download and bundle LFM2 700M model
- [ ] Implement LFM2Service with LEAP SDK
- [ ] Test basic inference functionality
- [ ] Add memory management and monitoring
- [ ] Implement caching layer for repeated queries

### Phase 3: Transaction Processing (Week 2)
- [ ] Implement transaction parsing with LFM2
- [ ] Add category classification
- [ ] Connect to CSV import flow
- [ ] Test with real transaction data
- [ ] Add progress indicators and UI feedback

### Phase 4: Insights & Analysis (Week 3)
- [ ] Implement spending analysis prompts
- [ ] Generate monthly insights
- [ ] Create cash flow visualizations
- [ ] Add trend detection
- [ ] Test accuracy and performance

### Phase 5: Budget Features (Week 3-4)
- [ ] Implement budget chat with context management
- [ ] Add budget recommendation generation
- [ ] Create budget vs actual comparison
- [ ] Implement savings goal tracking
- [ ] Polish conversation flow

### Phase 6: Optimization (Week 4)
- [ ] Performance profiling and optimization
- [ ] Reduce model loading time
- [ ] Implement streaming responses
- [ ] Add batch processing for bulk imports
- [ ] Memory usage optimization

## 5. Testing Strategy

### 5.1 Unit Tests
- Prompt template filling
- Configuration loading
- Fallback mechanisms
- Cache functionality

### 5.2 Integration Tests
- CSV import → LFM2 categorization flow
- Transaction analysis pipeline
- Budget chat conversation flow
- Memory management under load

### 5.3 Performance Benchmarks
- Model load time: < 3 seconds
- Single inference: < 500ms
- Batch processing: 100 transactions/minute
- Memory usage: < 2GB peak

## 6. Telemetry & Debugging

### 6.1 Console Telemetry Logger
```swift
// Services/TelemetryLogger.swift
class TelemetryLogger {
    static let shared = TelemetryLogger()
    
    enum LogLevel: String {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case success = "✅ SUCCESS"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case performance = "⏱️ PERF"
    }
    
    struct InferenceMetrics {
        let promptType: String
        let inputLength: Int
        let outputLength: Int
        let processingTime: TimeInterval
        let memoryUsed: Double // MB
        let success: Bool
        let errorMessage: String?
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(message)")
        #endif
    }
    
    func logInference(_ metrics: InferenceMetrics) {
        #if DEBUG
        let status = metrics.success ? "SUCCESS" : "FAILED"
        print("""
        
        ======= LFM2 INFERENCE \(status) =======
        📝 Type: \(metrics.promptType)
        📊 Input: \(metrics.inputLength) tokens | Output: \(metrics.outputLength) tokens
        ⏱️ Time: \(String(format: "%.3f", metrics.processingTime))s
        💾 Memory: \(String(format: "%.2f", metrics.memoryUsed)) MB
        \(metrics.errorMessage.map { "❌ Error: \($0)" } ?? "")
        =====================================
        
        """)
        #endif
    }
    
    func startTimer(_ label: String) -> DispatchTime {
        let start = DispatchTime.now()
        log(.performance, "Starting: \(label)")
        return start
    }
    
    func endTimer(_ label: String, start: DispatchTime) {
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        log(.performance, "Completed: \(label) in \(String(format: "%.3f", timeInterval))s")
    }
    
    func logMemoryUsage() {
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
            let memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            log(.performance, "Memory usage: \(String(format: "%.2f", memoryMB)) MB")
        }
    }
}
```

### 6.2 Telemetry Integration Points

```swift
// Services/LFM2Service.swift - Enhanced with telemetry
class LFM2Service {
    private let logger = TelemetryLogger.shared
    
    func inference(_ prompt: String, type: String = "general") async throws -> String {
        let startTime = logger.startTimer("LFM2 Inference - \(type)")
        logger.logMemoryUsage()
        
        var metrics = TelemetryLogger.InferenceMetrics(
            promptType: type,
            inputLength: prompt.count,
            outputLength: 0,
            processingTime: 0,
            memoryUsed: 0,
            success: false,
            errorMessage: nil
        )
        
        do {
            logger.log(.info, "Starting inference for \(type)")
            logger.log(.debug, "Prompt preview: \(String(prompt.prefix(100)))...")
            
            let result = try await leapSDK.generate(prompt: prompt)
            
            let endTime = DispatchTime.now()
            let processingTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
            
            metrics.outputLength = result.count
            metrics.processingTime = processingTime
            metrics.success = true
            
            logger.log(.success, "Inference completed for \(type)")
            logger.logInference(metrics)
            logger.endTimer("LFM2 Inference - \(type)", start: startTime)
            
            return result
        } catch {
            metrics.errorMessage = error.localizedDescription
            logger.log(.error, "Inference failed: \(error)")
            logger.logInference(metrics)
            throw error
        }
    }
}
```

### 6.3 Transaction Processing Telemetry

```swift
// Services/LFM2Manager.swift - Enhanced telemetry
class LFM2Manager: ObservableObject {
    private let logger = TelemetryLogger.shared
    
    func processBatchTransactions(_ transactions: [String]) async throws -> [ProcessedTransaction] {
        logger.log(.info, "Starting batch processing for \(transactions.count) transactions")
        let batchStart = logger.startTimer("Batch Transaction Processing")
        
        var successCount = 0
        var failureCount = 0
        var results: [ProcessedTransaction] = []
        
        for (index, transaction) in transactions.enumerated() {
            logger.log(.debug, "Processing transaction \(index + 1)/\(transactions.count)")
            
            do {
                let category = try await categorizeTransaction(transaction)
                results.append(ProcessedTransaction(text: transaction, category: category))
                successCount += 1
                logger.log(.success, "Transaction \(index + 1) categorized as: \(category)")
            } catch {
                failureCount += 1
                logger.log(.warning, "Failed to categorize transaction \(index + 1): \(error)")
                // Fallback to keyword matching
                let fallbackCategory = performKeywordMatching(transaction)
                results.append(ProcessedTransaction(text: transaction, category: fallbackCategory, isFallback: true))
            }
        }
        
        logger.endTimer("Batch Transaction Processing", start: batchStart)
        logger.log(.info, """
            Batch processing complete:
            ✅ Success: \(successCount)
            ❌ Failed: \(failureCount)
            📊 Success rate: \(String(format: "%.1f", Double(successCount) / Double(transactions.count) * 100))%
            """)
        
        return results
    }
}
```

### 6.4 Performance Monitoring

```swift
// Services/PerformanceMonitor.swift
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private let logger = TelemetryLogger.shared
    
    struct SessionStats {
        var totalInferences = 0
        var successfulInferences = 0
        var failedInferences = 0
        var totalProcessingTime: TimeInterval = 0
        var averageProcessingTime: TimeInterval {
            totalInferences > 0 ? totalProcessingTime / Double(totalInferences) : 0
        }
        var successRate: Double {
            totalInferences > 0 ? Double(successfulInferences) / Double(totalInferences) * 100 : 0
        }
    }
    
    private var sessionStats = SessionStats()
    
    func recordInference(success: Bool, processingTime: TimeInterval) {
        sessionStats.totalInferences += 1
        sessionStats.totalProcessingTime += processingTime
        
        if success {
            sessionStats.successfulInferences += 1
        } else {
            sessionStats.failedInferences += 1
        }
        
        // Log every 10 inferences
        if sessionStats.totalInferences % 10 == 0 {
            printSessionStats()
        }
    }
    
    func printSessionStats() {
        logger.log(.info, """
            
            📊 === SESSION STATISTICS ===
            Total Inferences: \(sessionStats.totalInferences)
            Success Rate: \(String(format: "%.1f", sessionStats.successRate))%
            Avg Processing Time: \(String(format: "%.3f", sessionStats.averageProcessingTime))s
            Total Processing Time: \(String(format: "%.2f", sessionStats.totalProcessingTime))s
            ✅ Successful: \(sessionStats.successfulInferences)
            ❌ Failed: \(sessionStats.failedInferences)
            ===========================
            
            """)
    }
}
```

### 6.5 Debug Configuration

```swift
// Config/LFM2Config.swift - Updated with telemetry settings
struct LFM2Config {
    // ... existing config ...
    
    // Telemetry Configuration
    static let enableTelemetry = true
    static let telemetryVerbosity: TelemetryLogger.LogLevel = .info
    static let logInferenceDetails = true
    static let logMemoryUsage = true
    static let logPerformanceMetrics = true
    static let sessionStatsInterval = 10 // Log stats every N inferences
}
```

### 6.6 Usage Examples

```swift
// Example: CSV Import with telemetry
func importCSV(_ fileURL: URL) async {
    let logger = TelemetryLogger.shared
    logger.log(.info, "Starting CSV import from: \(fileURL.lastPathComponent)")
    
    let importTimer = logger.startTimer("CSV Import")
    
    do {
        let transactions = try await CSVProcessor.parse(fileURL)
        logger.log(.success, "Parsed \(transactions.count) transactions from CSV")
        
        let categorizedTransactions = try await lfm2Manager.processBatchTransactions(transactions)
        logger.log(.success, "Categorized all transactions")
        
        try await dataManager.save(categorizedTransactions)
        logger.log(.success, "Saved transactions to Core Data")
        
        logger.endTimer("CSV Import", start: importTimer)
        PerformanceMonitor.shared.printSessionStats()
        
    } catch {
        logger.log(.error, "CSV import failed: \(error)")
    }
}
```

## 7. Fallback Strategy

When LFM2 is unavailable or fails:
1. Use keyword-based categorization
2. Show cached insights if available
3. Provide pre-written budget templates
4. Log errors with telemetry for debugging
5. Gracefully degrade features

## 8. Success Metrics

- Categorization accuracy: > 85%
- Inference speed: < 500ms per transaction
- App size with model: < 600MB
- Memory usage: < 2GB
- User-perceived latency: < 2 seconds
- Crash rate: < 0.1%

## 9. File Changes Required

### New Files to Create:
```
Vera/Config/
├── LFM2Config.swift
├── Environment.swift
└── LEAPConfig.swift

Vera/Prompts/
├── TransactionParser.prompt
├── CategoryClassifier.prompt
├── InsightsAnalyzer.prompt
├── BudgetNegotiator.prompt
└── BudgetInsights.prompt

Vera/Services/
├── LFM2Service.swift
├── PromptManager.swift
├── CacheManager.swift
├── TelemetryLogger.swift
└── PerformanceMonitor.swift
```

### Files to Modify:
- `LFM2Manager.swift` - Replace mock logic with real LFM2 calls
- `InsightsView.swift` - Use real analysis instead of mock data
- `BudgetChatView.swift` - Connect to LFM2 for responses
- `CSVProcessor.swift` - Add LFM2 categorization
- `Package.swift` - Add LEAP SDK dependency

## 10. Dependencies

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/liquid-ai/leap-ios-sdk", from: "1.0.0")
]
```

### Model File
- Download LFM2-700M.mlmodel from Liquid AI
- Add to project bundle
- Ensure proper code signing

## 11. Implementation Checklist

- [ ] Create configuration architecture
- [ ] Set up prompt management system
- [ ] Integrate LEAP SDK
- [ ] Bundle LFM2 model
- [ ] Implement transaction categorization
- [ ] Connect insights analysis
- [ ] Add budget chat functionality
- [ ] Implement progress tracking
- [ ] Add error handling
- [ ] Create fallback mechanisms
- [ ] Test with real data
- [ ] Optimize performance
- [ ] Document API usage
- [ ] Create user guides
- [ ] Implement telemetry logging system
- [ ] Add performance monitoring
- [ ] Set up console debugging output