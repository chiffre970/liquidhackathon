import Foundation
import LeapSDK

@available(iOS 15.0, *)
class LEAPSDKManager {
    private var modelRunner: ModelRunner?
    private var conversation: Conversation?
    private let modelQueue = DispatchQueue(label: "com.vera.leap.model", qos: .userInitiated)
    
    static let shared = LEAPSDKManager()
    
    private init() {}
    
    func initialize() async throws {
        // Look for the model bundle in the app
        guard let modelURL = Bundle.main.url(forResource: "lfm2-700m", withExtension: "bundle") else {
            // Try alternate extensions
            if let onnxURL = Bundle.main.url(forResource: "lfm2-700m", withExtension: "onnx") {
                throw LEAPError.modelNotFound("Found .onnx file but LeapSDK requires .bundle format. Please convert the model.")
            }
            throw LEAPError.modelNotFound("Model file 'lfm2-700m.bundle' not found in app bundle")
        }
        
        // Load the model using LeapSDK
        do {
            modelRunner = try await Leap.load(url: modelURL)
            
            // Create a conversation instance for managing chat interactions
            conversation = Conversation(modelRunner: modelRunner!, history: [])
        } catch {
            throw LEAPError.modelLoadFailed("Failed to load model: \(error.localizedDescription)")
        }
    }
    
    func generate(prompt: String, maxTokens: Int = 512) async throws -> String {
        guard let conversation = conversation else {
            throw LEAPError.modelNotInitialized
        }
        
        // Create a user message
        let userMessage = ChatMessage(role: .user, content: [.text(prompt)])
        
        var generatedText = ""
        
        // Generate response with streaming
        for await response in conversation.generateResponse(message: userMessage) {
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
                
            case .reasoningChunk(_):
                // We don't need reasoning chunks for basic generation
                continue
                
            case .complete(_, _):
                // Generation complete
                break
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
                guard let conversation = conversation else {
                    continuation.finish(throwing: LEAPError.modelNotInitialized)
                    return
                }
                
                let userMessage = ChatMessage(role: .user, content: [.text(prompt)])
                var totalGenerated = 0
                
                do {
                    for await response in conversation.generateResponse(message: userMessage) {
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
                            
                        case .reasoningChunk(_):
                            // Skip reasoning chunks
                            continue
                            
                        case .complete(_, _):
                            continuation.finish()
                            return
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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