import Foundation

struct LEAPConfig {
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let topK: Int
    let seed: Int?
    let stopTokens: [String]
    let timeout: TimeInterval
    
    init(
        maxTokens: Int = LFM2Config.maxTokens,
        temperature: Double = LFM2Config.temperature,
        topP: Double = LFM2Config.topP,
        topK: Int = LFM2Config.topK,
        seed: Int? = nil,
        stopTokens: [String] = [],
        timeout: TimeInterval = TimeInterval(LFM2Config.timeoutSeconds)
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.seed = seed
        self.stopTokens = stopTokens
        self.timeout = timeout
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "max_tokens": maxTokens,
            "temperature": temperature,
            "top_p": topP,
            "top_k": topK,
            "timeout": timeout
        ]
        
        if let seed = seed {
            dict["seed"] = seed
        }
        
        if !stopTokens.isEmpty {
            dict["stop_tokens"] = stopTokens
        }
        
        return dict
    }
}