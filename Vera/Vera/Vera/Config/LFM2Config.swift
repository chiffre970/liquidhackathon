import Foundation

struct LFM2Config {
    // Model Configuration
    static let defaultModelSize: LEAPSDKManager.ModelSize = .small  // Default to 350M for faster performance
    static let modelName = "lfm2"
    static let maxTokens = 512
    static let temperature = 0.6  // Lower for more consistent output
    static let topP = 0.85
    static let topK = 30
    
    // Processing Configuration
    static let batchSize = 15
    static let maxConcurrentTasks = 4
    static let timeoutSeconds = 20
    static let cacheEnabled = false  // Disable for real-time accuracy
    static let cacheExpirationHours = 24
    
    // Memory Management
    static let maxMemoryMB = 2048
    static let lowMemoryThreshold = 0.8
    
    // Feature Flags
    static let useStreamingInference = true
    static let enableDebugLogging = false  // Disable for production
    
    // Telemetry Configuration
    static let enableTelemetry = true
    static let telemetryVerbosity: TelemetryLogger.LogLevel = .warning  // Only warnings and errors
    static let logInferenceDetails = false
    static let logMemoryUsage = true
    static let logPerformanceMetrics = true
    static let sessionStatsInterval = 100 // Log stats every N inferences
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
    let cacheEnabled = false  // Disable for real-time accuracy
    let enableDebugLogging = false
}