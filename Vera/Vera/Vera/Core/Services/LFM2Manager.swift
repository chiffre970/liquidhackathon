import Foundation
import SwiftUI
import LeapSDK

class LFM2Manager: ObservableObject {
    static let shared = LFM2Manager()
    
    private var isModelLoaded = false
    private let modelQueue = DispatchQueue(label: "com.vera.lfm2", qos: .userInitiated)
    
    // Leap SDK model runner
    private var modelRunner: ModelRunner?
    
    struct ModelConfiguration {
        var maxTokens: Int
        var temperature: Float
        var topP: Float
        var streamingEnabled: Bool
        
        static let summary = ModelConfiguration(
            maxTokens: 2048,
            temperature: 0.7,
            topP: 0.9,
            streamingEnabled: true
        )
        
        static let extraction = ModelConfiguration(
            maxTokens: 512,
            temperature: 0.3,
            topP: 0.9,
            streamingEnabled: false
        )
    }
    
    enum LFM2Error: LocalizedError {
        case modelNotLoaded
        case modelLoadFailed(String)
        case generationFailed(String)
        case invalidResponse
        case outOfMemory
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "LFM2 model is not loaded"
            case .modelLoadFailed(let reason):
                return "Failed to load LFM2 model: \(reason)"
            case .generationFailed(let reason):
                return "Failed to generate response: \(reason)"
            case .invalidResponse:
                return "Invalid response from model"
            case .outOfMemory:
                return "Model ran out of memory"
            case .timeout:
                return "Model inference timed out"
            }
        }
    }
    
    private init() {}
    
    func initialize() async {
        do {
            try await loadModel()
            await warmupModel()
        } catch {
            print("Failed to initialize LFM2: \(error)")
        }
    }
    
    func loadModel() async throws {
        // Get bundle path - DO NOT EXTRACT
        guard let bundlePath = Bundle.main.path(
            forResource: "LFM2-700M-8da4w_output_8da8w-seq_4096",
            ofType: "bundle"
        ) else {
            throw LFM2Error.modelLoadFailed("Bundle not found")
        }
        
        print("📦 Loading LFM2 model from: \(bundlePath)")
        
        // Initialize Leap SDK - load model from bundle URL
        let bundleURL = URL(fileURLWithPath: bundlePath)
        self.modelRunner = try await Leap.load(url: bundleURL)
        
        self.isModelLoaded = true
        print("✅ LFM2 model loaded successfully")
        
        // Optimize for device memory
        await optimizeForDevice()
    }
    
    func warmupModel() async {
        guard isModelLoaded else { return }
        
        _ = try? await generate(
            prompt: "Hello",
            configuration: ModelConfiguration(
                maxTokens: 5,
                temperature: 0.5,
                topP: 0.9,
                streamingEnabled: false
            )
        )
        print("🔥 Model warmed up")
    }
    
    func generate(prompt: String, configuration: ModelConfiguration) async throws -> String {
        guard isModelLoaded else {
            throw LFM2Error.modelNotLoaded
        }
        
        // Use real Leap SDK inference
        guard let runner = modelRunner else {
            throw LFM2Error.modelNotLoaded
        }
        
        // Create conversation with system prompt
        let systemMessage = ChatMessage(
            role: .system,
            content: [.text("You are a helpful AI assistant that analyzes meeting transcripts and provides structured insights.")]
        )
        
        let userMessage = ChatMessage(
            role: .user,
            content: [.text(prompt)]
        )
        
        let conversation = Conversation(
            modelRunner: runner,
            history: [systemMessage]
        )
        
        // Generate response (collect all chunks)
        var fullResponse = ""
        let responseStream = conversation.generateResponse(message: userMessage)
        
        do {
            for try await response in responseStream {
                switch response {
                case .chunk(let text):
                    fullResponse += text
                case .reasoningChunk(_):
                    // Ignore reasoning chunks for now
                    break
                case .complete(_, _):
                    // Response is complete
                    break
                @unknown default:
                    // Handle any future cases
                    break
                }
            }
        } catch {
            throw LFM2Error.generationFailed("Stream error: \(error)")
        }
        
        return fullResponse
    }
    
    func generateJSON<T: Decodable>(
        prompt: String,
        configuration: ModelConfiguration,
        responseType: T.Type
    ) async throws -> T {
        // Add JSON instruction to prompt
        let jsonPrompt = """
        \(prompt)
        
        Respond with valid JSON only. No explanation or markdown.
        """
        
        // Generate response with JSON-focused parameters
        var jsonConfig = configuration
        jsonConfig.temperature = min(0.3, configuration.temperature) // Lower temperature for structured output
        
        let jsonString = try await generate(prompt: jsonPrompt, configuration: jsonConfig)
        
        // Clean response (remove any markdown if present)
        let cleanedJson = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedJson.data(using: .utf8) else {
            throw LFM2Error.invalidResponse
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ Failed to decode JSON: \(error)")
            print("Raw response: \(cleanedJson)")
            throw LFM2Error.invalidResponse
        }
    }
    
    func unloadModel() {
        modelQueue.async { [weak self] in
            self?.isModelLoaded = false
            print("🗑️ Model unloaded from memory")
        }
    }
    
    var isLoaded: Bool {
        return isModelLoaded
    }
    
    // Memory Management
    func optimizeForDevice() async {
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        
        if availableMemory < 4_000_000_000 {  // Less than 4GB
            // Note: Precision control may need to be handled at model load time
            print("📱 Device has <4GB RAM - using optimized settings")
        }
        
        // Note: Memory limits may need to be configured differently with Leap SDK
    }
    
    func handleMemoryPressure() {
        // Note: Cache clearing may need to be handled differently with Leap SDK
        print("⚠️ Handling memory pressure")
        // Consider recreating the model runner if needed
    }
    
    // Error handling with retry logic
    func generateWithRetry(prompt: String, configuration: ModelConfiguration, retries: Int = 2) async throws -> String {
        var lastError: Error?
        var currentConfig = configuration
        
        for attempt in 0...retries {
            do {
                return try await generate(prompt: prompt, configuration: currentConfig)
            } catch LFM2Error.outOfMemory {
                handleMemoryPressure()
                // Retry with truncated prompt
                let truncatedPrompt = String(prompt.prefix(2000))
                return try await generate(prompt: truncatedPrompt, configuration: currentConfig)
            } catch LFM2Error.timeout {
                // Retry with shorter max tokens
                currentConfig.maxTokens = min(256, currentConfig.maxTokens / 2)
                lastError = LFM2Error.timeout
                if attempt < retries {
                    print("⏰ Timeout, retrying with maxTokens: \(currentConfig.maxTokens)")
                }
            } catch {
                lastError = error
                if attempt < retries {
                    print("❌ Generation failed, attempt \(attempt + 1)/\(retries + 1)")
                }
            }
        }
        
        throw lastError ?? LFM2Error.generationFailed("All retry attempts failed")
    }
}

extension LFM2Manager {
    struct SummaryResponse: Codable {
        let executiveSummary: String
        let keyPoints: [String]
        let criticalInfo: String?
        let unresolvedTopics: [String]
    }
}