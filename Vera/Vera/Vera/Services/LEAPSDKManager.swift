import Foundation
import Leap

@available(iOS 15.0, *)
class LEAPSDKManager {
    // Model size enum for easy selection
    enum ModelSize: String, CaseIterable {
        case small = "350M"
        case medium = "700M"
        case large = "1.2B"
        
        var fileName: String {
            switch self {
            case .small:
                return "LFM2-350M-8da4w_output_8da8w-seq_4096"
            case .medium:
                return "LFM2-700M-8da4w_output_8da8w-seq_4096"
            case .large:
                return "LFM2-1.2B-8da4w_output_8da8w-seq_4096"
            }
        }
        
        var displayName: String {
            return "LFM2-\(self.rawValue)"
        }
    }
    
    private var modelRunner: ModelRunner?
    private var conversation: Conversation?
    private let modelQueue = DispatchQueue(label: "com.vera.leap.model", qos: .userInitiated)
    private var currentModelSize: ModelSize?
    
    static let shared = LEAPSDKManager()
    
    private init() {}
    
    // Initialize with specific model size
    func initialize(modelSize: ModelSize = .small) async throws {
        // Check if we're already using this model
        if currentModelSize == modelSize, modelRunner != nil {
            print("Model \(modelSize.displayName) already loaded")
            return
        }
        
        // Unload previous model if any
        if modelRunner != nil {
            unload()
        }
        
        // Look for the model bundle in the app
        guard let modelURL = Bundle.main.url(
            forResource: modelSize.fileName,
            withExtension: "bundle"
        ) else {
            throw LEAPError.modelNotFound("Model file '\(modelSize.fileName).bundle' not found in app bundle")
        }
        
        print("Loading model: \(modelSize.displayName) from \(modelURL.lastPathComponent)")
        
        // Load the model using LeapSDK (following the quick start guide pattern)
        do {
            modelRunner = try await Leap.load(url: modelURL)
            
            // Create a conversation instance for managing chat interactions
            conversation = Conversation(modelRunner: modelRunner!, history: [])
            currentModelSize = modelSize
            
            print("Successfully loaded \(modelSize.displayName)")
        } catch {
            throw LEAPError.modelLoadFailed("Failed to load \(modelSize.displayName): \(error.localizedDescription)")
        }
    }
    
    func generate(prompt: String, maxTokens: Int = 512) async throws -> String {
        guard let modelRunner = modelRunner else {
            throw LEAPError.modelNotInitialized
        }
        
        // Create fresh conversation for single-turn generation
        let conversation = Conversation(modelRunner: modelRunner, history: [])
        
        // Create a user message
        let userMessage = ChatMessage(role: .user, content: [.text(prompt)])
        
        var generatedText = ""
        
        // Generate response with streaming
        let stream = conversation.generateResponse(message: userMessage)
        
        for await response in stream {
            switch response {
            case .chunk(let text):
                generatedText += text
                
                // Check for early stopping conditions
                if generatedText.count >= maxTokens {
                    break
                }
                
                // Check for stop sequences
                if generatedText.contains("\n\n") || generatedText.contains("END") {
                    break
                }
                
            case .complete(_, _):
                // Generation complete
                break
                
            default:
                // Handle any other cases
                continue
            }
        }
        
        // Clean up the response
        if let stopIndex = generatedText.firstIndex(of: "\n\n") {
            generatedText = String(generatedText[..<stopIndex])
        } else if let endIndex = generatedText.range(of: "END") {
            generatedText = String(generatedText[..<endIndex.lowerBound])
        }
        
        return generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func generateStream(prompt: String, maxTokens: Int = 512) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let modelRunner = modelRunner else {
                    continuation.finish(throwing: LEAPError.modelNotInitialized)
                    return
                }
                
                // Create fresh conversation for streaming
                let conversation = Conversation(modelRunner: modelRunner, history: [])
                let userMessage = ChatMessage(role: .user, content: [.text(prompt)])
                var totalGenerated = 0
                
                let stream = conversation.generateResponse(message: userMessage)
                
                do {
                    for await response in stream {
                        switch response {
                        case .chunk(let text):
                            continuation.yield(text)
                            totalGenerated += text.count
                            
                            // Check max tokens
                            if totalGenerated >= maxTokens {
                                continuation.finish()
                                return
                            }
                            
                            // Check stop sequences
                            if text.contains("\n\n") || text.contains("END") {
                                continuation.finish()
                                return
                            }
                            
                        case .complete(_, _):
                            continuation.finish()
                            return
                            
                        default:
                            // Handle any other cases
                            continue
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // For chat conversations with history
    func generateWithHistory(prompt: String, history: [ChatMessage], maxTokens: Int = 512) async throws -> String {
        guard let modelRunner = modelRunner else {
            throw LEAPError.modelNotInitialized
        }
        
        // Create conversation with history
        let conversation = Conversation(modelRunner: modelRunner, history: history)
        
        // Create a user message
        let userMessage = ChatMessage(role: .user, content: [.text(prompt)])
        
        var generatedText = ""
        
        // Generate response with streaming
        let stream = conversation.generateResponse(message: userMessage)
        
        for await response in stream {
            switch response {
            case .chunk(let text):
                generatedText += text
                
                if generatedText.count >= maxTokens {
                    break
                }
                
            case .complete(_, _):
                break
                
            default:
                continue
            }
        }
        
        return generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func resetConversation() {
        // Reset conversation history while keeping the model loaded
        if let modelRunner = modelRunner {
            conversation = Conversation(modelRunner: modelRunner, history: [])
        }
    }
    
    func unload() {
        modelRunner = nil
        conversation = nil
        currentModelSize = nil
    }
    
    // Get current model size
    func getCurrentModelSize() -> ModelSize? {
        return currentModelSize
    }
    
    // Switch to a different model
    func switchModel(to modelSize: ModelSize) async throws {
        await MainActor.run {
            print("Switching from \(currentModelSize?.displayName ?? "none") to \(modelSize.displayName)")
        }
        try await initialize(modelSize: modelSize)
    }
}

enum LEAPError: LocalizedError {
    case modelNotFound(String)
    case modelNotInitialized
    case modelLoadFailed(String)
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let details):
            return "Model not found: \(details)"
        case .modelNotInitialized:
            return "Model not initialized. Please call initialize() first."
        case .modelLoadFailed(let details):
            return "Failed to load model: \(details)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}