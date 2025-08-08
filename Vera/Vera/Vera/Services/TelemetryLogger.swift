import Foundation
import os.log

class TelemetryLogger {
    static let shared = TelemetryLogger()
    
    enum LogLevel: String, CaseIterable {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case success = "✅ SUCCESS"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case performance = "⏱️ PERF"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .success: return .default
            case .warning: return .default
            case .error: return .error
            case .performance: return .info
            }
        }
    }
    
    struct InferenceMetrics {
        let promptType: String
        let inputLength: Int
        let outputLength: Int
        let processingTime: TimeInterval
        let memoryUsed: Double // MB
        let success: Bool
        let errorMessage: String?
        
        init(
            promptType: String,
            inputLength: Int,
            outputLength: Int = 0,
            processingTime: TimeInterval = 0,
            memoryUsed: Double = 0,
            success: Bool = false,
            errorMessage: String? = nil
        ) {
            self.promptType = promptType
            self.inputLength = inputLength
            self.outputLength = outputLength
            self.processingTime = processingTime
            self.memoryUsed = memoryUsed
            self.success = success
            self.errorMessage = errorMessage
        }
    }
    
    private let subsystem = "com.vera.lfm2"
    private let osLog: OSLog
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    private let logQueue = DispatchQueue(label: "com.vera.telemetry", qos: .utility)
    
    private init() {
        self.osLog = OSLog(subsystem: subsystem, category: "LFM2")
    }
    
    func log(
        _ level: LogLevel,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard shouldLog(level: level) else { return }
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            #if DEBUG
            let timestamp = self.dateFormatter.string(from: Date())
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            let logMessage = "[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(message)"
            print(logMessage)
            #endif
            
            os_log("%{public}@", log: self.osLog, type: level.osLogType, message)
        }
    }
    
    func logInference(_ metrics: InferenceMetrics) {
        guard LFM2Config.logInferenceDetails else { return }
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            #if DEBUG
            let status = metrics.success ? "SUCCESS" : "FAILED"
            let inferenceLog = """
            
            ======= LFM2 INFERENCE \(status) =======
            📝 Type: \(metrics.promptType)
            📊 Input: \(metrics.inputLength) tokens | Output: \(metrics.outputLength) tokens
            ⏱️ Time: \(String(format: "%.3f", metrics.processingTime))s
            💾 Memory: \(String(format: "%.2f", metrics.memoryUsed)) MB
            \(metrics.errorMessage.map { "❌ Error: \($0)" } ?? "")
            =====================================
            
            """
            print(inferenceLog)
            #endif
            
            // Also log to os_log for production monitoring
            let logMessage = "Inference \(metrics.success ? "succeeded" : "failed") - Type: \(metrics.promptType), Time: \(String(format: "%.3f", metrics.processingTime))s"
            os_log("%{public}@", log: self.osLog, type: metrics.success ? .info : .error, logMessage)
        }
    }
    
    func startTimer(_ label: String) -> DispatchTime {
        let start = DispatchTime.now()
        if LFM2Config.logPerformanceMetrics {
            log(.performance, "Starting: \(label)")
        }
        return start
    }
    
    func endTimer(_ label: String, start: DispatchTime) {
        guard LFM2Config.logPerformanceMetrics else { return }
        
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        log(.performance, "Completed: \(label) in \(String(format: "%.3f", timeInterval))s")
    }
    
    func logMemoryUsage() {
        guard LFM2Config.logMemoryUsage else { return }
        
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
            
            // Check memory threshold
            let memoryRatio = memoryMB / Double(LFM2Config.maxMemoryMB)
            if memoryRatio > LFM2Config.lowMemoryThreshold {
                log(.warning, "Memory usage high: \(String(format: "%.1f", memoryRatio * 100))% of max")
            }
        }
    }
    
    func logBatch<T>(
        operation: String,
        items: [T],
        success: Int,
        failed: Int,
        duration: TimeInterval
    ) {
        let successRate = items.isEmpty ? 0 : Double(success) / Double(items.count) * 100
        
        log(.info, """
            Batch \(operation) complete:
            ✅ Success: \(success)
            ❌ Failed: \(failed)
            📊 Success rate: \(String(format: "%.1f", successRate))%
            ⏱️ Duration: \(String(format: "%.2f", duration))s
            """)
    }
    
    private func shouldLog(level: LogLevel) -> Bool {
        guard LFM2Config.enableTelemetry else { return false }
        
        // In debug mode, log everything
        #if DEBUG
        return true
        #else
        // In release, respect verbosity setting
        let currentLevelIndex = LogLevel.allCases.firstIndex(of: level) ?? 0
        let verbosityIndex = LogLevel.allCases.firstIndex(of: LFM2Config.telemetryVerbosity) ?? 0
        return currentLevelIndex >= verbosityIndex
        #endif
    }
    
    // MARK: - Convenience Methods
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.success, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
    
    func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.performance, message, file: file, function: function, line: line)
    }
}