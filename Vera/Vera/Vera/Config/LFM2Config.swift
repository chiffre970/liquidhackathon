import Foundation

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
    static let enableDebugLogging = true
    static let fallbackToKeywordMatching = true
    
    // Telemetry Configuration
    static let enableTelemetry = true
    static let telemetryVerbosity: TelemetryLogger.LogLevel = .info
    static let logInferenceDetails = true
    static let logMemoryUsage = true
    static let logPerformanceMetrics = true
    static let sessionStatsInterval = 10 // Log stats every N inferences
}

protocol LFM2ConfigProtocol {
    var maxTokens: Int { get }
    var temperature: Double { get }
    var topP: Double { get }
    var topK: Int { get }
    var batchSize: Int { get }
    var maxConcurrentTasks: Int { get }
    var timeoutSeconds: Int { get }
    var cacheEnabled: Bool { get }
    var enableDebugLogging: Bool { get }
}

struct LFM2ConfigDev: LFM2ConfigProtocol {
    let maxTokens = 512
    let temperature = 0.7
    let topP = 0.9
    let topK = 40
    let batchSize = 5
    let maxConcurrentTasks = 2
    let timeoutSeconds = 60
    let cacheEnabled = true
    let enableDebugLogging = true
}

struct LFM2ConfigStaging: LFM2ConfigProtocol {
    let maxTokens = 512
    let temperature = 0.7
    let topP = 0.9
    let topK = 40
    let batchSize = 10
    let maxConcurrentTasks = 3
    let timeoutSeconds = 30
    let cacheEnabled = true
    let enableDebugLogging = false
}

struct LFM2ConfigProd: LFM2ConfigProtocol {
    let maxTokens = 512
    let temperature = 0.6
    let topP = 0.85
    let topK = 30
    let batchSize = 15
    let maxConcurrentTasks = 4
    let timeoutSeconds = 20
    let cacheEnabled = true
    let enableDebugLogging = false
}