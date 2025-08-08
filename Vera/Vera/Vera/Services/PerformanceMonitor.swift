import Foundation

class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private let logger = TelemetryLogger.shared
    private let queue = DispatchQueue(label: "com.vera.performance", attributes: .concurrent)
    
    struct SessionStats {
        var totalInferences = 0
        var successfulInferences = 0
        var failedInferences = 0
        var totalProcessingTime: TimeInterval = 0
        var peakMemoryUsage: Double = 0 // MB
        var minProcessingTime: TimeInterval = Double.infinity
        var maxProcessingTime: TimeInterval = 0
        var inferencesByType: [String: Int] = [:]
        var errorsByType: [String: Int] = [:]
        var startTime: Date = Date()
        
        var averageProcessingTime: TimeInterval {
            totalInferences > 0 ? totalProcessingTime / Double(totalInferences) : 0
        }
        
        var successRate: Double {
            totalInferences > 0 ? Double(successfulInferences) / Double(totalInferences) * 100 : 0
        }
        
        var sessionDuration: TimeInterval {
            Date().timeIntervalSince(startTime)
        }
        
        var inferencesPerMinute: Double {
            let minutes = sessionDuration / 60
            return minutes > 0 ? Double(totalInferences) / minutes : 0
        }
    }
    
    struct InferenceRecord {
        let id: UUID
        let type: String
        let startTime: Date
        let endTime: Date
        let success: Bool
        let inputSize: Int
        let outputSize: Int
        let memoryUsed: Double
        let error: String?
        
        var processingTime: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
    }
    
    private var sessionStats = SessionStats()
    private var recentInferences: [InferenceRecord] = []
    private let maxRecentInferences = 100
    private var activeInferences: [UUID: (type: String, start: Date)] = [:]
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        logger.warning("Memory warning received")
        logCurrentMemoryUsage()
        clearRecentInferences()
    }
    
    func startInference(type: String) -> UUID {
        let id = UUID()
        
        queue.async(flags: .barrier) { [weak self] in
            self?.activeInferences[id] = (type: type, start: Date())
        }
        
        return id
    }
    
    func endInference(
        id: UUID,
        success: Bool,
        inputSize: Int = 0,
        outputSize: Int = 0,
        error: String? = nil
    ) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let inferenceInfo = self.activeInferences.removeValue(forKey: id) else {
                return
            }
            
            let endTime = Date()
            let processingTime = endTime.timeIntervalSince(inferenceInfo.start)
            let memoryUsed = self.getCurrentMemoryUsage()
            
            // Create record
            let record = InferenceRecord(
                id: id,
                type: inferenceInfo.type,
                startTime: inferenceInfo.start,
                endTime: endTime,
                success: success,
                inputSize: inputSize,
                outputSize: outputSize,
                memoryUsed: memoryUsed,
                error: error
            )
            
            // Update stats
            self.updateStats(with: record)
            
            // Store recent inference
            self.recentInferences.append(record)
            if self.recentInferences.count > self.maxRecentInferences {
                self.recentInferences.removeFirst()
            }
            
            // Log if milestone reached
            if self.sessionStats.totalInferences % LFM2Config.sessionStatsInterval == 0 {
                self.printSessionStats()
            }
        }
    }
    
    func recordInference(
        type: String,
        success: Bool,
        processingTime: TimeInterval,
        inputSize: Int = 0,
        outputSize: Int = 0
    ) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.sessionStats.totalInferences += 1
            self.sessionStats.totalProcessingTime += processingTime
            
            if success {
                self.sessionStats.successfulInferences += 1
            } else {
                self.sessionStats.failedInferences += 1
            }
            
            // Update type tracking
            self.sessionStats.inferencesByType[type, default: 0] += 1
            if !success {
                self.sessionStats.errorsByType[type, default: 0] += 1
            }
            
            // Update min/max times
            self.sessionStats.minProcessingTime = min(self.sessionStats.minProcessingTime, processingTime)
            self.sessionStats.maxProcessingTime = max(self.sessionStats.maxProcessingTime, processingTime)
            
            // Update peak memory
            let currentMemory = self.getCurrentMemoryUsage()
            self.sessionStats.peakMemoryUsage = max(self.sessionStats.peakMemoryUsage, currentMemory)
            
            // Log every N inferences
            if self.sessionStats.totalInferences % LFM2Config.sessionStatsInterval == 0 {
                self.printSessionStats()
            }
        }
    }
    
    private func updateStats(with record: InferenceRecord) {
        sessionStats.totalInferences += 1
        sessionStats.totalProcessingTime += record.processingTime
        
        if record.success {
            sessionStats.successfulInferences += 1
        } else {
            sessionStats.failedInferences += 1
            sessionStats.errorsByType[record.type, default: 0] += 1
        }
        
        sessionStats.inferencesByType[record.type, default: 0] += 1
        sessionStats.minProcessingTime = min(sessionStats.minProcessingTime, record.processingTime)
        sessionStats.maxProcessingTime = max(sessionStats.maxProcessingTime, record.processingTime)
        sessionStats.peakMemoryUsage = max(sessionStats.peakMemoryUsage, record.memoryUsed)
    }
    
    func printSessionStats() {
        queue.sync {
            let stats = sessionStats
            
            logger.info("""
                
                📊 === SESSION STATISTICS ===
                Total Inferences: \(stats.totalInferences)
                Success Rate: \(String(format: "%.1f", stats.successRate))%
                Avg Processing Time: \(String(format: "%.3f", stats.averageProcessingTime))s
                Min/Max Time: \(String(format: "%.3f", stats.minProcessingTime == Double.infinity ? 0 : stats.minProcessingTime))s / \(String(format: "%.3f", stats.maxProcessingTime))s
                Total Processing Time: \(String(format: "%.2f", stats.totalProcessingTime))s
                Peak Memory: \(String(format: "%.2f", stats.peakMemoryUsage)) MB
                Throughput: \(String(format: "%.1f", stats.inferencesPerMinute)) inferences/min
                Session Duration: \(String(format: "%.1f", stats.sessionDuration / 60)) minutes
                ✅ Successful: \(stats.successfulInferences)
                ❌ Failed: \(stats.failedInferences)
                ===========================
                
                """)
            
            if !stats.inferencesByType.isEmpty {
                logger.info("Inferences by Type:")
                for (type, count) in stats.inferencesByType.sorted(by: { $0.value > $1.value }) {
                    let errors = stats.errorsByType[type] ?? 0
                    let successRate = errors == 0 ? 100 : Double(count - errors) / Double(count) * 100
                    logger.info("  - \(type): \(count) (Success: \(String(format: "%.1f", successRate))%)")
                }
            }
        }
    }
    
    func getSessionStats() -> SessionStats {
        return queue.sync { sessionStats }
    }
    
    func getRecentInferences() -> [InferenceRecord] {
        return queue.sync { recentInferences }
    }
    
    func resetStats() {
        queue.async(flags: .barrier) { [weak self] in
            self?.sessionStats = SessionStats()
            self?.recentInferences.removeAll()
            self?.logger.info("Performance statistics reset")
        }
    }
    
    private func clearRecentInferences() {
        queue.async(flags: .barrier) { [weak self] in
            self?.recentInferences.removeAll(keepingCapacity: true)
            self?.logger.info("Cleared recent inference history to free memory")
        }
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
    
    private func logCurrentMemoryUsage() {
        let memoryMB = getCurrentMemoryUsage()
        logger.performance("Current memory usage: \(String(format: "%.2f", memoryMB)) MB")
    }
    
    // MARK: - Performance Benchmarks
    
    func runBenchmark(iterations: Int = 10, block: () async throws -> Void) async {
        logger.info("Starting performance benchmark with \(iterations) iterations")
        
        var times: [TimeInterval] = []
        var successes = 0
        
        for i in 1...iterations {
            let start = Date()
            
            do {
                try await block()
                successes += 1
            } catch {
                logger.error("Benchmark iteration \(i) failed: \(error)")
            }
            
            let elapsed = Date().timeIntervalSince(start)
            times.append(elapsed)
        }
        
        let averageTime = times.reduce(0, +) / Double(times.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        
        logger.info("""
            
            🏁 === BENCHMARK RESULTS ===
            Iterations: \(iterations)
            Success Rate: \(String(format: "%.1f", Double(successes) / Double(iterations) * 100))%
            Average Time: \(String(format: "%.3f", averageTime))s
            Min Time: \(String(format: "%.3f", minTime))s
            Max Time: \(String(format: "%.3f", maxTime))s
            ===========================
            
            """)
    }
}