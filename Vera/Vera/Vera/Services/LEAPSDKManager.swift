import Foundation
import LeapSDK

@available(iOS 15.0, *)
class LEAPSDKManager {
    // Using only the 350M model for mobile efficiency
    private let modelFileName = "LFM2-350M-8da4w_output_8da8w-seq_4096"
    private let modelDisplayName = "LFM2-350M"
    
    private var modelRunner: LeapSDK.ModelRunner?
    private var conversation: LeapSDK.Conversation?
    private let modelQueue = DispatchQueue(label: "com.vera.leap.model", qos: .userInitiated)
    private var isModelLoaded = false
    
    static let shared = LEAPSDKManager()
    
    private init() {}
    
    // Initialize the 350M model
    func initialize() async throws {
        // Check if model is already loaded
        if isModelLoaded, modelRunner != nil {
            print("Model \(modelDisplayName) already loaded")
            return
        }
        
        // Look for the model bundle in the app
        guard let modelURL = Bundle.main.url(
            forResource: modelFileName,
            withExtension: "bundle"
        ) else {
            throw LEAPError.modelNotFound("Model file '\(modelFileName).bundle' not found in app bundle")
        }
        
        print("Loading model: \(modelDisplayName) from \(modelURL.lastPathComponent)")
        
        // Load the model using LeapSDK
        do {
            modelRunner = try await LeapSDK.Leap.load(url: modelURL)
            
            // Create a conversation instance for managing chat interactions
            conversation = LeapSDK.Conversation(modelRunner: modelRunner!, history: [])
            isModelLoaded = true
            
            print("Successfully loaded \(modelDisplayName)")
        } catch {
            throw LEAPError.modelLoadFailed("Failed to load \(modelDisplayName): \(error.localizedDescription)")
        }
    }
    
    func generate(prompt: String, maxTokens: Int = 512) async throws -> String {
        guard let modelRunner = modelRunner else {
            throw LEAPError.modelNotInitialized
        }
        
        // Create fresh conversation for single-turn generation
        let conversation = LeapSDK.Conversation(modelRunner: modelRunner, history: [])
        
        // Create a user message
        let userMessage = LeapSDK.ChatMessage(role: .user, content: [.text(prompt)])
        
        var generatedText = ""
        
        // Generate response with streaming
        let stream = conversation.generateResponse(message: userMessage)
        
        do {
            for try await response in stream {
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
        } catch {
            print("Error generating response: \(error)")
        }
        
        // Clean up the response
        if let stopIndex = generatedText.range(of: "\n\n") {
            generatedText = String(generatedText[..<stopIndex.lowerBound])
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
                let conversation = LeapSDK.Conversation(modelRunner: modelRunner, history: [])
                let userMessage = LeapSDK.ChatMessage(role: .user, content: [.text(prompt)])
                var totalGenerated = 0
                
                let stream = conversation.generateResponse(message: userMessage)
                
                do {
                    for try await response in stream {
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
    func generateWithHistory(prompt: String, history: [LeapSDK.ChatMessage], maxTokens: Int = 512) async throws -> String {
        guard let modelRunner = modelRunner else {
            throw LEAPError.modelNotInitialized
        }
        
        // Create conversation with history
        let conversation = LeapSDK.Conversation(modelRunner: modelRunner, history: history)
        
        // Create a user message
        let userMessage = LeapSDK.ChatMessage(role: .user, content: [.text(prompt)])
        
        var generatedText = ""
        
        // Generate response with streaming
        let stream = conversation.generateResponse(message: userMessage)
        
        do {
            for try await response in stream {
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
        } catch {
            print("Error generating constrained response: \(error)")
        }
        
        return generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func resetConversation() {
        // Reset conversation history while keeping the model loaded
        if let modelRunner = modelRunner {
            conversation = LeapSDK.Conversation(modelRunner: modelRunner, history: [])
        }
    }
    
    func unload() {
        modelRunner = nil
        conversation = nil
        isModelLoaded = false
    }
    
    // Check if model is loaded
    func isModelReady() -> Bool {
        return isModelLoaded && modelRunner != nil
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