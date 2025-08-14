import Foundation
import SwiftUI

class LFM2Manager: ObservableObject {
    static let shared = LFM2Manager()
    
    private var isModelLoaded = false
    private let modelQueue = DispatchQueue(label: "com.vera.lfm2", qos: .userInitiated)
    
    struct ModelConfiguration {
        let maxTokens: Int
        let temperature: Float
        let topP: Float
        let streamingEnabled: Bool
        
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
        return try await withCheckedThrowingContinuation { continuation in
            modelQueue.async { [weak self] in
                guard let self = self else { 
                    continuation.resume(throwing: LFM2Error.modelLoadFailed("Manager deallocated"))
                    return
                }
                
                do {
                    guard let modelPath = Bundle.main.path(forResource: "lfm_700m", ofType: "bundle") else {
                        throw LFM2Error.modelLoadFailed("Model bundle not found")
                    }
                    
                    print("📦 Loading LFM2 model from: \(modelPath)")
                    
                    self.isModelLoaded = true
                    print("✅ LFM2 model loaded successfully")
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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
        
        return try await withCheckedThrowingContinuation { continuation in
            modelQueue.async { [weak self] in
                guard self != nil else {
                    continuation.resume(throwing: LFM2Error.generationFailed("Manager deallocated"))
                    return
                }
                
                let simulatedResponse = self?.simulateResponse(for: prompt, config: configuration) ?? "Error: Manager deallocated"
                continuation.resume(returning: simulatedResponse)
            }
        }
    }
    
    func generateJSON<T: Decodable>(
        prompt: String,
        configuration: ModelConfiguration,
        responseType: T.Type
    ) async throws -> T {
        let jsonString = try await generate(prompt: prompt, configuration: configuration)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw LFM2Error.invalidResponse
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ Failed to decode JSON: \(error)")
            print("Raw response: \(jsonString)")
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
    
    private func simulateResponse(for prompt: String, config: ModelConfiguration) -> String {
        if prompt.contains("extract") && prompt.contains("action items") {
            return """
            [
                {
                    "task": "Follow up with the client about the proposal",
                    "owner": "John",
                    "deadline": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600)))",
                    "priority": "high",
                    "context": "Client expressed interest but needs more details"
                },
                {
                    "task": "Prepare the quarterly report",
                    "owner": "Sarah",
                    "deadline": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(3 * 24 * 3600)))",
                    "priority": "medium",
                    "context": "For the board meeting next week"
                }
            ]
            """
        } else if prompt.contains("identify") && prompt.contains("decisions") {
            return """
            [
                {
                    "decision": "Proceed with the new feature development",
                    "context": "Team agreed the feature aligns with Q1 goals",
                    "impact": "Will require 2 additional developers",
                    "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
                },
                {
                    "decision": "Postpone the infrastructure upgrade",
                    "context": "Current system is stable enough for next quarter",
                    "impact": "Cost savings of $50K this quarter",
                    "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
                }
            ]
            """
        } else if prompt.contains("identify questions") {
            return """
            [
                {
                    "question": "What is the budget for the new project?",
                    "context": "Need to finalize resource allocation",
                    "assignedTo": "Finance team",
                    "urgency": "high"
                },
                {
                    "question": "Who will lead the customer success initiative?",
                    "context": "Position needs to be filled by next month",
                    "assignedTo": "HR",
                    "urgency": "medium"
                }
            ]
            """
        } else if prompt.contains("comprehensive") && prompt.contains("summary") {
            return """
            {
                "executiveSummary": "The team discussed Q1 priorities, focusing on product development and customer success. Key decisions were made regarding resource allocation and timeline adjustments.",
                "keyPoints": [
                    "New feature development approved for Q1",
                    "Customer success team expansion planned",
                    "Infrastructure upgrade postponed to Q2",
                    "Budget review scheduled for next week",
                    "Partnership opportunities identified"
                ],
                "criticalInfo": "Budget constraints may impact hiring timeline",
                "unresolvedTopics": [
                    "Final budget allocation",
                    "Technical architecture for new feature"
                ]
            }
            """
        } else {
            return "This is a simulated response from the LFM2 model for testing purposes."
        }
    }
}

extension LFM2Manager {
    struct ActionItemResponse: Codable {
        let task: String
        let owner: String?
        let deadline: String?
        let priority: String
        let context: String?
    }
    
    struct DecisionResponse: Codable {
        let decision: String
        let context: String?
        let impact: String?
        let timestamp: String
    }
    
    struct QuestionResponse: Codable {
        let question: String
        let context: String?
        let assignedTo: String?
        let urgency: String
    }
    
    struct SummaryResponse: Codable {
        let executiveSummary: String
        let keyPoints: [String]
        let criticalInfo: String?
        let unresolvedTopics: [String]
    }
}