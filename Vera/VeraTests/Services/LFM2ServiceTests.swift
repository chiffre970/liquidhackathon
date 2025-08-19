import XCTest
@testable import Vera

@available(iOS 15.0, *)
final class LFM2ServiceTests: XCTestCase {
    
    var lfm2Service: LFM2Service!
    var lfm2Manager: LFM2Manager!
    
    override func setUp() {
        super.setUp()
        lfm2Service = LFM2Service.shared
        lfm2Manager = LFM2Manager.shared
    }
    
    override func tearDown() {
        CacheManager.shared.clearAll()
        PerformanceMonitor.shared.resetStats()
        super.tearDown()
    }
    
    // MARK: - Basic Inference Tests
    
    func testBasicInference() async throws {
        let prompt = "Test prompt for inference"
        let result = try await lfm2Service.inference(prompt, type: "test")
        
        XCTAssertFalse(result.isEmpty, "Inference result should not be empty")
        XCTAssertTrue(result.count > 0, "Result should have content")
    }
    
    func testCategorization() async throws {
        let testTransactions = [
            "Starbucks Coffee $5.50",
            "Walmart Grocery $125.30",
            "Netflix Subscription $15.99",
            "Uber Ride $22.00",
            "Dr. Smith Medical $150.00"
        ]
        
        for transaction in testTransactions {
            let category = await lfm2Manager.categorizeTransaction(transaction)
            
            XCTAssertFalse(category.isEmpty, "Category should not be empty")
            XCTAssertTrue(
                ["Housing", "Food", "Transportation", "Healthcare", 
                 "Entertainment", "Shopping", "Savings", "Utilities", "Other"].contains(category),
                "Category should be valid: \(category)"
            )
            
            print("Transaction: \(transaction) -> Category: \(category)")
        }
    }
    
    // MARK: - Batch Processing Tests
    
    func testBatchProcessing() async throws {
        let transactions = [
            "Grocery Store $45.00",
            "Gas Station $60.00",
            "Restaurant $35.00"
        ]
        
        let results = try await lfm2Manager.processBatchTransactions(transactions)
        
        XCTAssertEqual(results.count, transactions.count, "Should process all transactions")
        
        for result in results {
            XCTAssertFalse(result.category.isEmpty, "Each transaction should have a category")
        }
    }
    
    // MARK: - Cache Tests
    
    func testCaching() async throws {
        let prompt = "Test caching prompt"
        let type = "cache_test"
        
        // First call - should hit the model
        let result1 = try await lfm2Service.inference(prompt, type: type)
        
        // Second call - should hit the cache
        let result2 = try await lfm2Service.inference(prompt, type: type)
        
        XCTAssertEqual(result1, result2, "Cached result should match original")
    }
    
    func testCacheExpiration() async throws {
        let cacheManager = CacheManager.shared
        let key = "test_expiration"
        let value = "test_value"
        
        // Cache with 0 hours expiration (immediately expired)
        cacheManager.cache(value, forKey: key, expirationHours: 0)
        
        // Wait a moment
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        let retrieved = cacheManager.retrieve(forKey: key)
        XCTAssertNil(retrieved, "Expired cache should return nil")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceMonitoring() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Perform some inferences
        for i in 1...5 {
            let id = monitor.startInference(type: "perf_test")
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 second
            monitor.endInference(id: id, success: true, inputSize: 100, outputSize: 200)
        }
        
        let stats = monitor.getSessionStats()
        XCTAssertEqual(stats.totalInferences, 5, "Should have 5 inferences")
        XCTAssertEqual(stats.successfulInferences, 5, "All should be successful")
        XCTAssertEqual(stats.successRate, 100.0, "Success rate should be 100%")
    }
    
    // MARK: - Telemetry Tests
    
    func testTelemetryLogging() {
        let logger = TelemetryLogger.shared
        
        // Test different log levels
        logger.debug("Debug message")
        logger.info("Info message")
        logger.success("Success message")
        logger.warning("Warning message")
        logger.error("Error message")
        logger.performance("Performance message")
        
        // Test inference metrics
        let metrics = TelemetryLogger.InferenceMetrics(
            promptType: "test",
            inputLength: 100,
            outputLength: 200,
            processingTime: 0.5,
            memoryUsed: 50.0,
            success: true,
            errorMessage: nil
        )
        
        logger.logInference(metrics)
        
        // Test timer
        let start = logger.startTimer("Test Operation")
        logger.endTimer("Test Operation", start: start)
        
        // No assertions - just verifying no crashes
        XCTAssertTrue(true, "Telemetry logging should not crash")
    }
    
    // MARK: - Prompt Management Tests
    
    func testPromptManager() {
        let promptManager = PromptManager.shared
        
        // Test loading prompts
        let categoryPrompt = promptManager.loadPrompt(.categoryClassifier)
        XCTAssertFalse(categoryPrompt.isEmpty, "Should load category classifier prompt")
        
        // Test template filling
        let variables = [
            "merchant_name": "Test Store",
            "amount": "100.00"
        ]
        
        let filledPrompt = promptManager.fillTemplate(categoryPrompt, variables: variables)
        XCTAssertTrue(filledPrompt.contains("Test Store"), "Should replace merchant_name")
        XCTAssertTrue(filledPrompt.contains("100.00"), "Should replace amount")
    }
    
    // MARK: - Fallback Tests
    
    func testFallbackCategorization() async {
        let manager = LFM2Manager.shared
        
        // Test keyword matching fallback
        let testCases = [
            ("Rent payment", "Housing"),
            ("Grocery store", "Food"),
            ("Uber ride", "Transportation"),
            ("Doctor visit", "Healthcare"),
            ("Netflix", "Entertainment"),
            ("Amazon purchase", "Shopping"),
            ("Savings deposit", "Savings"),
            ("Electric bill", "Utilities"),
            ("Random text", "Other")
        ]
        
        for (text, expectedCategory) in testCases {
            let category = await manager.categorizeTransaction(text)
            XCTAssertEqual(category, expectedCategory, 
                          "'\(text)' should be categorized as '\(expectedCategory)', got '\(category)'")
        }
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndTransactionProcessing() async throws {
        let csvData = """
        Date,Description,Amount
        2024-01-01,Starbucks Coffee,-5.50
        2024-01-02,Salary Deposit,3000.00
        2024-01-03,Walmart Grocery,-125.30
        """
        
        let transactions = csvData.components(separatedBy: "\n")
            .dropFirst() // Skip header
            .compactMap { line -> String? in
                let parts = line.components(separatedBy: ",")
                guard parts.count >= 3 else { return nil }
                return "\(parts[1]) \(parts[2])"
            }
        
        let results = try await lfm2Manager.processBatchTransactions(transactions)
        
        XCTAssertEqual(results.count, 3, "Should process 3 transactions")
        
        // Verify categories make sense
        XCTAssertTrue(["Food", "Entertainment"].contains(results[0].category), 
                     "Coffee should be Food or Entertainment")
        XCTAssertEqual(results[1].category, "Income", 
                      "Salary should be Income")
        XCTAssertTrue(["Food", "Shopping"].contains(results[2].category), 
                     "Grocery should be Food or Shopping")
    }
    
    // MARK: - Benchmark Tests
    
    func testInferenceBenchmark() async throws {
        await PerformanceMonitor.shared.runBenchmark(iterations: 10) {
            _ = try await self.lfm2Service.inference("Benchmark test prompt", type: "benchmark")
        }
        
        let stats = PerformanceMonitor.shared.getSessionStats()
        XCTAssertGreaterThan(stats.totalInferences, 0, "Should have completed inferences")
        
        print("Benchmark Results:")
        print("  Average time: \(stats.averageProcessingTime)s")
        print("  Success rate: \(stats.successRate)%")
    }
}