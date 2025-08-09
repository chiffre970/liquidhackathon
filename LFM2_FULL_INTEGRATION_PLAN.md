# LFM2 Full Integration Plan - Remove All Mocks

## Executive Summary
This plan outlines the complete integration of the LEAP SDK and LFM2 model, replacing ALL mock implementations with real functionality. No fallbacks, no mocks, no placeholders.

## Phase 1: LEAP SDK Integration (Day 1-2)

### 1.1 Add LEAP SDK Dependency

```swift
// Package.swift or Xcode Project Settings
dependencies: [
    .package(url: "https://github.com/liquid-ai/leap-ios-sdk", from: "1.0.0")
]

targets: [
    .target(
        name: "Vera",
        dependencies: [
            .product(name: "LEAPKit", package: "leap-ios-sdk")
        ]
    )
]
```

### 1.2 Create LEAP SDK Wrapper

```swift
// Services/LEAPSDKManager.swift
import Foundation
import LEAPKit

@available(iOS 15.0, *)
class LEAPSDKManager {
    private var model: LEAPModel?
    private let modelQueue = DispatchQueue(label: "com.vera.leap.model", qos: .userInitiated)
    
    static let shared = LEAPSDKManager()
    
    private init() {}
    
    func initialize() async throws {
        guard let modelPath = Bundle.main.path(forResource: "lfm2-700m", ofType: "onnx") else {
            throw LEAPError.modelNotFound
        }
        
        let config = LEAPConfiguration(
            modelPath: modelPath,
            maxSequenceLength: 512,
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            useGPU: true,
            memoryLimit: 2048 // MB
        )
        
        model = try await LEAPModel.load(configuration: config)
    }
    
    func generate(prompt: String, maxTokens: Int = 512) async throws -> String {
        guard let model = model else {
            throw LEAPError.modelNotInitialized
        }
        
        let request = LEAPGenerationRequest(
            prompt: prompt,
            maxTokens: maxTokens,
            stopSequences: ["\n\n", "END"],
            stream: false
        )
        
        let response = try await model.generate(request)
        return response.text
    }
    
    func generateStream(prompt: String, maxTokens: Int = 512) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let model = model else {
                    continuation.finish(throwing: LEAPError.modelNotInitialized)
                    return
                }
                
                let request = LEAPGenerationRequest(
                    prompt: prompt,
                    maxTokens: maxTokens,
                    stream: true
                )
                
                do {
                    for try await chunk in model.generateStream(request) {
                        continuation.yield(chunk.text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func unload() {
        model = nil
    }
}

enum LEAPError: LocalizedError {
    case modelNotFound
    case modelNotInitialized
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "LFM2 model file not found in bundle"
        case .modelNotInitialized:
            return "LFM2 model not initialized"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}
```

## Phase 2: Replace LFM2Service Mock Implementation (Day 2-3)

### 2.1 Complete LFM2Service Rewrite

```swift
// Services/LFM2Service.swift - COMPLETE REPLACEMENT
import Foundation
import LEAPKit

@available(iOS 15.0, *)
class LFM2Service {
    private let logger = TelemetryLogger.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let config: LFM2ConfigProtocol
    private let promptManager = PromptManager.shared
    private let leapSDK = LEAPSDKManager.shared
    
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
    
    // MARK: - Core Inference (NO MOCKS)
    
    func inference(_ prompt: String, type: String = "general") async throws -> String {
        let inferenceId = performanceMonitor.startInference(type: type)
        let startTime = logger.startTimer("LFM2 Inference - \(type)")
        
        do {
            logger.info("Starting LFM2 inference for \(type)")
            logger.debug("Prompt: \(String(prompt.prefix(100)))...")
            
            // REAL INFERENCE - NO MOCK
            let result = try await leapSDK.generate(
                prompt: prompt,
                maxTokens: config.maxTokens
            )
            
            performanceMonitor.endInference(
                id: inferenceId,
                success: true,
                inputSize: prompt.count,
                outputSize: result.count
            )
            
            logger.success("LFM2 inference completed for \(type)")
            logger.endTimer("LFM2 Inference - \(type)", start: startTime)
            
            return result
        } catch {
            performanceMonitor.endInference(
                id: inferenceId,
                success: false,
                inputSize: prompt.count,
                outputSize: 0,
                error: error.localizedDescription
            )
            
            logger.error("LFM2 inference failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Specialized Methods (ALL REAL)
    
    func categorizeTransaction(_ text: String, context: [String] = []) async throws -> String {
        let prompt = promptManager.loadPrompt(.categoryClassifier)
        let filled = promptManager.fillTemplate(prompt, variables: [
            "transaction": text,
            "context": context.joined(separator: ", ")
        ])
        
        let result = try await inference(filled, type: "CategoryClassifier")
        
        // Parse the category from response
        let category = extractCategory(from: result)
        guard !category.isEmpty else {
            throw LFM2Error.invalidResponse("Could not extract category from LFM2 response")
        }
        
        return category
    }
    
    func analyzeSpending(_ transactions: [[String: Any]]) async throws -> String {
        let prompt = promptManager.loadPrompt(.insightsAnalyzer)
        let transactionsJSON = try JSONSerialization.data(withJSONObject: transactions)
        let transactionsString = String(data: transactionsJSON, encoding: .utf8) ?? "[]"
        
        let filled = promptManager.fillTemplate(prompt, variables: [
            "transactions": transactionsString,
            "month": getCurrentMonth(),
            "year": getCurrentYear()
        ])
        
        return try await inference(filled, type: "InsightsAnalyzer")
    }
    
    func negotiateBudget(
        currentSpending: [String: Double],
        userMessage: String,
        chatHistory: [String] = []
    ) async throws -> String {
        let prompt = promptManager.loadPrompt(.budgetNegotiator)
        let spendingJSON = try JSONSerialization.data(withJSONObject: currentSpending)
        let spendingString = String(data: spendingJSON, encoding: .utf8) ?? "{}"
        
        let filled = promptManager.fillTemplate(prompt, variables: [
            "spending": spendingString,
            "message": userMessage,
            "history": chatHistory.joined(separator: "\n")
        ])
        
        return try await inference(filled, type: "BudgetNegotiator")
    }
    
    // MARK: - Helper Methods
    
    private func extractCategory(from response: String) -> String {
        // Categories we expect
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
    
    private func getCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }
    
    private func getCurrentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
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
```

## Phase 3: Remove ALL Mock Code from LFM2Manager (Day 3)

### 3.1 Update LFM2Manager - Remove Fallbacks

```swift
// Services/LFM2Manager.swift - KEY CHANGES
@available(iOS 15.0, *)
class LFM2Manager: ObservableObject {
    // ... existing properties ...
    
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
            // NO FALLBACK - Real LFM2 only
            let category = try await lfm2Service.categorizeTransaction(text, context: context)
            logger.success("Transaction categorized as: \(category)")
            return category
        } catch {
            logger.error("Failed to categorize transaction: \(error)")
            throw error // Propagate error instead of fallback
        }
    }
    
    func processBatchTransactions(_ transactions: [String]) async throws -> [ProcessedTransaction] {
        // ... existing setup ...
        
        for (index, transaction) in transactions.enumerated() {
            do {
                let context = index > 0 ? Array(transactions[max(0, index-5)..<index]) : []
                let category = try await lfm2Service.categorizeTransaction(transaction, context: context)
                results.append(ProcessedTransaction(text: transaction, category: category))
                successCount += 1
            } catch {
                // NO FALLBACK - Report actual errors
                failureCount += 1
                logger.error("Failed to categorize transaction \(index + 1): \(error)")
                throw error // Stop processing on error
            }
        }
        
        return results
    }
    
    // REMOVE performKeywordMatching() method entirely
    // REMOVE generateSpendingAnalysis() method entirely
    // REMOVE all fallback response arrays
}
```

## Phase 4: Create Actual Prompt Files (Day 3-4)

### 4.1 Create Prompt Directory and Files

```bash
mkdir -p Vera/Vera/Vera/Prompts
```

### 4.2 CategoryClassifier.prompt

```
You are a financial transaction categorizer for a personal finance app.

TASK: Categorize the following transaction into EXACTLY ONE category.

TRANSACTION: {transaction}
RECENT CONTEXT: {context}

CATEGORIES (choose only one):
- Housing (rent, mortgage, property tax, home insurance)
- Food (groceries, restaurants, delivery, coffee shops)
- Transportation (gas, public transit, uber, car payment, auto insurance)
- Healthcare (doctor, dentist, pharmacy, health insurance)
- Entertainment (movies, concerts, streaming services, games)
- Shopping (clothing, electronics, general retail)
- Savings (transfers to savings, investments)
- Utilities (electricity, water, gas, internet, phone)
- Income (salary, freelance, refunds, deposits)
- Other (anything that doesn't fit above)

OUTPUT: Return ONLY the category name, nothing else.
```

### 4.3 InsightsAnalyzer.prompt

```
Analyze the following financial transactions and provide actionable insights.

TRANSACTIONS DATA:
{transactions}

PERIOD: {month} {year}

ANALYSIS REQUIREMENTS:
1. Identify top 3 spending categories with percentages
2. Compare to typical spending patterns
3. Detect unusual or concerning trends
4. Highlight positive financial behaviors
5. Provide 3 specific, actionable recommendations

FORMAT: 
- Use bullet points
- Include specific dollar amounts
- Keep under 200 words
- Be encouraging but realistic

OUTPUT your analysis:
```

### 4.4 BudgetNegotiator.prompt

```
You are a helpful financial advisor assisting with budget planning.

CURRENT SPENDING:
{spending}

USER MESSAGE:
{message}

CONVERSATION HISTORY:
{history}

YOUR ROLE:
- Suggest realistic budget allocations (as percentages)
- Be conversational and supportive
- Acknowledge user concerns
- Provide specific, actionable advice
- Use the 50/30/20 rule as a starting guideline

CONSTRAINTS:
- Response under 150 words
- Include specific percentages
- Suggest one immediate action

RESPOND:
```

### 4.5 TransactionParser.prompt

```
Parse the following raw transaction text into structured data.

RAW TRANSACTION:
{raw_text}

EXTRACT:
1. Merchant/Counterparty name
2. Amount (as decimal number, negative for debits)
3. Date (YYYY-MM-DD format)
4. Transaction type (debit/credit)

OUTPUT FORMAT:
merchant: [name]
amount: [number]
date: [YYYY-MM-DD]
type: [debit/credit]
```

### 4.6 BudgetInsights.prompt

```
Compare budget allocations with actual spending and provide optimization insights.

BUDGET ALLOCATIONS:
{budget}

ACTUAL SPENDING:
{actual}

SAVINGS GOAL:
{savings_goal}

PROVIDE:
1. Budget adherence score (0-100)
2. Categories over/under budget (with amounts)
3. Top 3 optimization opportunities
4. Realistic timeline to reach savings goal
5. One behavioral change recommendation

FORMAT:
- Use structured sections
- Include specific numbers and percentages
- Be constructive, not critical

OUTPUT:
```

## Phase 5: Update PromptManager (Day 4)

### 5.1 Remove ALL Fallback Prompts

```swift
// Services/PromptManager.swift - UPDATED
class PromptManager {
    static let shared = PromptManager()
    private var prompts: [String: String] = [:]
    private let promptQueue = DispatchQueue(label: "com.vera.promptmanager", attributes: .concurrent)
    
    private init() {
        loadAllPrompts()
    }
    
    private func loadAllPrompts() {
        for promptType in PromptType.allCases {
            guard let prompt = loadPromptFromFile(promptType.fileName) else {
                fatalError("Required prompt file missing: \(promptType.fileName)")
            }
            prompts[promptType.rawValue] = prompt
        }
    }
    
    private func loadPromptFromFile(_ fileName: String) -> String? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Prompts") else {
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
        guard let prompt = prompts[type.rawValue] else {
            fatalError("Prompt not loaded: \(type.rawValue)")
        }
        return prompt
    }
    
    // REMOVE getFallbackPrompt() method entirely
}
```

## Phase 6: Bundle LFM2 Model (Day 4-5)

### 6.1 Model Integration Steps

1. **Download LFM2-700M model** from Liquid AI
2. **Convert to Core ML format** (if needed):
   ```bash
   python convert_to_coreml.py --model lfm2-700m.onnx --output lfm2-700m.mlpackage
   ```

3. **Add to Xcode project**:
   - Drag `lfm2-700m.mlpackage` to project
   - Ensure "Copy items if needed" is checked
   - Add to target membership

4. **Update Info.plist**:
   ```xml
   <key>UIRequiredDeviceCapabilities</key>
   <array>
       <string>arm64</string>
       <string>metal</string>
   </array>
   <key>MinimumOSVersion</key>
   <string>15.0</string>
   ```

## Phase 7: Remove ALL Mock/Fallback Code (Day 5)

### 7.1 Files to Clean

1. **LFM2Service.swift**:
   - Remove `simulateInference()` method
   - Remove `fallbackInference()` method
   - Remove `performKeywordCategorization()` method
   - Remove `generateMockInsights()` method
   - Remove `generateMockBudgetResponse()` method

2. **LFM2Manager.swift**:
   - Remove `performKeywordMatching()` method
   - Remove `generateSpendingAnalysis()` method
   - Remove `parseSpendingFromMessage()` method
   - Remove all hardcoded response arrays

3. **LFM2Config.swift**:
   - Remove `fallbackToKeywordMatching` flag
   - Update all feature flags to production values

## Phase 8: Update Configuration (Day 5)

### 8.1 Production Configuration

```swift
// Config/LFM2Config.swift - PRODUCTION READY
struct LFM2Config {
    // Model Configuration
    static let modelName = "lfm2-700m"
    static let modelPath = Bundle.main.path(forResource: "lfm2-700m", ofType: "mlpackage")
    static let maxTokens = 512
    static let temperature = 0.6  // Lower for more consistent output
    static let topP = 0.85
    static let topK = 30
    
    // Processing Configuration
    static let batchSize = 15
    static let maxConcurrentTasks = 4
    static let timeoutSeconds = 20
    static let cacheEnabled = false  // Disable for real-time accuracy
    
    // Memory Management
    static let maxMemoryMB = 2048
    static let lowMemoryThreshold = 0.8
    
    // Feature Flags
    static let useStreamingInference = true
    static let enableDebugLogging = false  // Disable for production
    
    // Telemetry Configuration
    static let enableTelemetry = true
    static let telemetryVerbosity: TelemetryLogger.LogLevel = .warning  // Only warnings and errors
}
```

## Phase 9: Error Handling Without Fallbacks (Day 6)

### 9.1 Update Error Handling

```swift
// ViewModels/TransactionViewModel.swift
class TransactionViewModel: ObservableObject {
    @Published var error: LFM2Error?
    @Published var isRetrying = false
    
    func processTransaction(_ transaction: String) async {
        do {
            let category = try await lfm2Manager.categorizeTransaction(transaction)
            // Process successful categorization
        } catch {
            self.error = error as? LFM2Error ?? .unknown(error)
            // Show error to user - NO FALLBACK
        }
    }
    
    func retry() async {
        isRetrying = true
        error = nil
        // Retry the operation
        isRetrying = false
    }
}
```

## Phase 10: Testing Without Mocks (Day 6-7)

### 10.1 Integration Tests

```swift
// Tests/LFM2IntegrationTests.swift
class LFM2IntegrationTests: XCTestCase {
    func testRealCategorization() async throws {
        // Test with REAL model
        let service = LFM2Service.shared
        let category = try await service.categorizeTransaction("Starbucks Coffee $5.50")
        
        XCTAssertTrue(["Food", "Entertainment"].contains(category))
    }
    
    func testRealBudgetNegotiation() async throws {
        // Test actual LFM2 responses
        let response = try await service.negotiateBudget(
            currentSpending: ["Food": 500, "Housing": 1500],
            userMessage: "I need to save more",
            chatHistory: []
        )
        
        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(response.contains("%"))  // Should include percentages
    }
}
```

## Implementation Checklist

### Week 1
- [ ] Set up LEAP SDK dependency
- [ ] Create LEAPSDKManager wrapper
- [ ] Replace LFM2Service mock implementation
- [ ] Remove all fallback methods from LFM2Manager
- [ ] Create all prompt files
- [ ] Update PromptManager to require prompts

### Week 2
- [ ] Bundle LFM2-700M model
- [ ] Test model loading and initialization
- [ ] Remove all mock/simulation methods
- [ ] Update configuration for production
- [ ] Implement proper error handling
- [ ] Create integration tests

### Testing Milestones
- [ ] Model loads successfully
- [ ] Single inference works
- [ ] Batch processing works
- [ ] All prompt types return valid responses
- [ ] Error handling works without fallbacks
- [ ] Memory usage stays under 2GB
- [ ] Performance meets targets (<500ms inference)

## Success Criteria

1. **NO MOCK CODE**: Zero fallback methods, zero hardcoded responses
2. **REAL INFERENCE**: Every AI call goes through actual LFM2 model
3. **PROMPT FILES**: All prompts loaded from actual files
4. **ERROR HANDLING**: Failures are reported, not hidden with fallbacks
5. **PERFORMANCE**: <500ms per inference, <2GB memory usage
6. **ACCURACY**: >90% correct categorization on test data

## Risk Mitigation

1. **Model Size**: If 700M model is too large, consider 400M variant
2. **Performance**: Implement request queuing if inference is slow
3. **Memory**: Add memory pressure handling to unload model if needed
4. **Errors**: Implement retry logic with exponential backoff

## Files to Delete

- All mock response methods
- Fallback prompt templates
- Keyword matching logic
- Hardcoded category lists (except for validation)
- Simulation/mock inference code

## Final Validation

Run this script to ensure no mock code remains:

```bash
#!/bin/bash
echo "Checking for mock/fallback code..."
grep -r "simulateInference\|fallbackInference\|performKeywordMatching\|generateMock\|fallback" Vera/
if [ $? -eq 0 ]; then
    echo "❌ Mock code still present!"
    exit 1
else
    echo "✅ No mock code found"
fi
```

This plan ensures COMPLETE integration with zero mocks or fallbacks.