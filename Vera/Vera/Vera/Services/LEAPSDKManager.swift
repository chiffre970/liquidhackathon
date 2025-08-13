import Foundation
import LeapSDK
// Import other LEAP modules if available
#if canImport(LeapSDKTypes)
import LeapSDKTypes
#endif

@available(iOS 15.0, *)
class LEAPSDKManager {
    // Using the 700M model for better quality while maintaining mobile efficiency
    private let modelFileName = "LFM2-700M-8da4w_output_8da8w-seq_4096"
    private let modelDisplayName = "LFM2-700M"
    
    private var modelRunner: LeapSDK.ModelRunner?
    private var conversation: LeapSDK.Conversation?
    private let modelQueue = DispatchQueue(label: "com.vera.leap.model", qos: .userInitiated)
    private var isModelLoaded = false
    
    static let shared = LEAPSDKManager()
    
    private init() {}
    
    // Initialize the 700M model
    func initialize() async throws {
        // Check if model is already loaded
        if isModelLoaded, modelRunner != nil {
            print("Model \(modelDisplayName) already loaded")
            return
        }
        
        // Look for the model bundle in the app
        // First, let's debug what's in the bundle
        print("🔍 Main bundle path: \(Bundle.main.bundlePath)")
        print("🔍 Main bundle resource path: \(Bundle.main.resourcePath ?? "nil")")
        
        // List all bundle contents for debugging
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("📦 Bundle contents: \(contents.filter { $0.contains("LFM2") || $0.contains(".bundle") })")
            } catch {
                print("❌ Could not list bundle contents: \(error)")
            }
        }
        
        var foundModelURL: URL? = Bundle.main.url(
            forResource: modelFileName,
            withExtension: "bundle"
        )
        
        // If not found in standard location, try alternative paths
        if foundModelURL == nil {
            let alternativePaths = [
                Bundle.main.bundleURL.appendingPathComponent("\(modelFileName).bundle"),
                Bundle.main.bundleURL.appendingPathComponent("Frameworks/\(modelFileName).bundle"),
                Bundle.main.resourceURL?.appendingPathComponent("\(modelFileName).bundle")
            ].compactMap { $0 }
            
            for path in alternativePaths {
                print("🔍 Checking alternative path: \(path.path)")
                if FileManager.default.fileExists(atPath: path.path) {
                    print("✅ Found model at alternative path!")
                    foundModelURL = path
                    break
                }
            }
        }
        
        guard let modelURL = foundModelURL else {
            throw LEAPError.modelNotFound("Model file '\(modelFileName).bundle' not found in app bundle")
        }
        
        // Copy the model bundle to a writable location (Library directory)
        // This is required because LEAP SDK needs to create cache files
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let writableModelURL = libraryURL.appendingPathComponent("\(modelFileName).bundle")
        
        if !FileManager.default.fileExists(atPath: writableModelURL.path) {
            do {
                try FileManager.default.copyItem(at: modelURL, to: writableModelURL)
                print("📄 Copied model bundle to writable Library directory: \(writableModelURL.path)")
            } catch {
                print("⚠️ Failed to copy model bundle to writable location: \(error)")
                print("Will attempt to load from read-only bundle (may fail)")
            }
        } else {
            print("📄 Writable model bundle already exists at: \(writableModelURL.path)")
        }
        
        // Use the writable copy if it exists, otherwise fallback to original
        let loadURL = FileManager.default.fileExists(atPath: writableModelURL.path) ? writableModelURL : modelURL
        
        print("Loading model: \(modelDisplayName) from \(loadURL.lastPathComponent)")
        print("Model URL path: \(loadURL.path)")
        
        // Verify the bundle exists and is accessible at the load location
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: loadURL.path) {
            print("✅ Model bundle file exists at load location")
            
            // Check if it's a directory (proper bundle) or a file
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: loadURL.path, isDirectory: &isDirectory)
            print("Is directory: \(isDirectory.boolValue)")
            
            // List contents of the bundle
            if isDirectory.boolValue {
                if let contents = try? fileManager.contentsOfDirectory(atPath: loadURL.path) {
                    print("Bundle contents at load location: \(contents)")
                }
            }
            
            // Get bundle size
            var totalSize: Int64 = 0
            if let enumerator = fileManager.enumerator(atPath: loadURL.path) {
                while let file = enumerator.nextObject() as? String {
                    let filePath = loadURL.appendingPathComponent(file).path
                    if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                       let fileSize = attributes[FileAttributeKey.size] as? Int64 {
                        totalSize += fileSize
                    }
                }
            }
            print("Total model size: \(totalSize / 1024 / 1024) MB")
        } else {
            print("❌ Model bundle file does NOT exist at load path")
        }
        
        // Check for required files in the bundle
        let modelFileURL = loadURL.appendingPathComponent("model.pte")
        let configFileURL = loadURL.appendingPathComponent("config.yaml")
        
        if fileManager.fileExists(atPath: modelFileURL.path) {
            print("✅ Found model.pte inside bundle")
        } else {
            print("⚠️ model.pte not found in bundle")
        }
        
        if fileManager.fileExists(atPath: configFileURL.path) {
            print("✅ Found config.yaml inside bundle")
        } else {
            print("⚠️ config.yaml not found in bundle")
        }
        
        // Load the model using LeapSDK - pass the bundle directory (not model.pte)
        do {
            print("Attempting to load model with LeapSDK from bundle directory...")
            print("Loading from: \(loadURL.path)")
            
            // LEAP SDK expects the bundle directory containing config.yaml and model.pte
            modelRunner = try await LeapSDK.Leap.load(url: loadURL)
            
            // Create a conversation instance for managing chat interactions
            conversation = LeapSDK.Conversation(modelRunner: modelRunner!, history: [])
            isModelLoaded = true
            
            print("✅ Successfully loaded \(modelDisplayName)")
        } catch {
            print("❌ Failed to load model: \(error)")
            print("Error type: \(type(of: error))")
            print("Error details: \(error.localizedDescription)")
            
            // If loading from writable location failed, try a clean copy
            if loadURL == writableModelURL {
                print("Attempting to remove and re-copy model bundle...")
                try? FileManager.default.removeItem(at: writableModelURL)
                
                do {
                    try FileManager.default.copyItem(at: modelURL, to: writableModelURL)
                    print("Re-copied model bundle, attempting load again...")
                    modelRunner = try await LeapSDK.Leap.load(url: writableModelURL)
                    conversation = LeapSDK.Conversation(modelRunner: modelRunner!, history: [])
                    isModelLoaded = true
                    print("✅ Successfully loaded after re-copy")
                } catch {
                    throw LEAPError.modelLoadFailed("Failed to load \(modelDisplayName) even after re-copy: \(error.localizedDescription)")
                }
            } else {
                throw LEAPError.modelLoadFailed("Failed to load \(modelDisplayName): \(error.localizedDescription)")
            }
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
                
                // Don't stop on double newlines - let the model complete its response
                // Only stop on explicit END marker if needed
                if generatedText.contains("<|END|>") {
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
        
        // Clean up the response - only remove explicit stop tokens
        if let endIndex = generatedText.range(of: "<|END|>") {
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
                            
                            // Check for explicit stop token only
                            if text.contains("<|END|>") {
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