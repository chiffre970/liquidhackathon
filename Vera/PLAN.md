# LFM2 Integration Plan - Using Leap SDK

## Overview
Replace mock LFM2 implementation with real model inference using Liquid AI's Leap SDK for iOS.
**Analysis happens ONCE when user ends recording - no streaming, single comprehensive prompt.**

## Key Requirements
1. **Remove all mock code** - Delete simulateResponse() and all hardcoded responses
2. **Use bundle directly** - The `.bundle` file should NOT be extracted
3. **Integrate Leap SDK** - Use Liquid AI's official SDK for model inference
4. **Single analysis** - Run ONE comprehensive prompt when recording ends
5. **Prompts in separate file** - All prompts in LFM2Prompts.swift

## Phase 1: Remove Mock Implementation ⚠️ CRITICAL FIRST STEP

### Files to modify:
**LFM2Manager.swift**
1. Delete entire `simulateResponse()` method (lines 151-226)
2. Delete test JSON responses
3. Update `generate()` method to use real inference

```swift
// DELETE lines 151-226 completely
private func simulateResponse(for prompt: String, config: ModelConfiguration) -> String {
    // DELETE ALL OF THIS
}

// UPDATE line 114 in generate() method
// OLD: let simulatedResponse = self?.simulateResponse(for: prompt, config: configuration)
// NEW: let response = try await self?.leapModel.generate(prompt, maxTokens: configuration.maxTokens)
```

## Phase 2: Integrate Leap SDK

### 1. Add Leap SDK to project
```swift
// Package.swift or via Swift Package Manager in Xcode
dependencies: [
    .package(url: "https://github.com/liquid-ai/leap-ios-sdk", from: "1.0.0")
]

// Or CocoaPods
pod 'LeapSDK', '~> 1.0'
```

### 2. Import and configure
```swift
import LeapSDK
import Foundation

class LFM2Manager: ObservableObject {
    private var leapModel: LeapModel?
    private var leapSession: LeapInferenceSession?
    
    func loadModel() async throws {
        // Get bundle path - DO NOT EXTRACT
        guard let bundlePath = Bundle.main.path(
            forResource: "LFM2-700M-8da4w_output_8da8w-seq_4096", 
            ofType: "bundle"
        ) else {
            throw LFM2Error.modelLoadFailed("Bundle not found")
        }
        
        // Initialize Leap with bundle directly
        let config = LeapModelConfiguration(
            bundlePath: bundlePath,
            device: .auto,  // Let SDK choose CPU/GPU/Neural Engine
            precision: .float16  // Or .int8 for smaller memory
        )
        
        // Load model through Leap SDK
        self.leapModel = try await LeapModel(configuration: config)
        self.leapSession = try await leapModel.createSession()
        self.isModelLoaded = true
    }
}
```

## Phase 3: Implement Real Inference

### 1. Replace generate() method (NO STREAMING - Single analysis at end)
```swift
func generate(prompt: String, configuration: ModelConfiguration) async throws -> String {
    guard let session = leapSession else {
        throw LFM2Error.modelNotLoaded
    }
    
    // Configure generation parameters - NO STREAMING
    let params = LeapGenerationParams(
        maxTokens: configuration.maxTokens,
        temperature: configuration.temperature,
        topP: configuration.topP,
        stopSequences: ["</s>", "\n\n", "```"],
        stream: false  // Always false - we want complete response at once
    )
    
    // Generate complete response using Leap SDK
    // This happens ONCE when user hits "End Recording"
    let response = try await session.generate(
        prompt: prompt,
        parameters: params
    )
    
    return response.text
}
```

### 2. Update generateJSON method
```swift
func generateJSON<T: Decodable>(
    prompt: String,
    configuration: ModelConfiguration,
    responseType: T.Type
) async throws -> T {
    // Add JSON instruction
    let jsonPrompt = """
    \(prompt)
    
    Respond with valid JSON only. No explanation or markdown.
    """
    
    // Use guided generation if Leap supports it
    let params = LeapGenerationParams(
        maxTokens: configuration.maxTokens,
        temperature: configuration.temperature,
        topP: configuration.topP,
        responseFormat: .json  // If Leap SDK supports structured output
    )
    
    let response = try await session.generate(
        prompt: jsonPrompt,
        parameters: params
    )
    
    // Parse JSON
    guard let data = response.text.data(using: .utf8) else {
        throw LFM2Error.invalidResponse
    }
    
    return try JSONDecoder().decode(T.self, from: data)
}
```

## Phase 4: Create Prompts File

### Create separate LFM2Prompts.swift file
```swift
// New file: Vera/Core/Services/LFM2Prompts.swift
import Foundation

struct LFM2Prompts {
    // SINGLE comprehensive prompt for post-recording analysis
    // This runs ONCE when user hits "End Recording"
    static func meetingAnalysis(transcript: String, userNotes: String?) -> String {
        """
        Analyze this complete meeting recording and provide comprehensive insights.
        
        Meeting Transcript:
        \(transcript)
        
        User Notes:
        \(userNotes ?? "None provided")
        
        Generate a JSON response with the following structure:
        {
            "executiveSummary": "2-3 sentence overview of the entire meeting",
            "keyPoints": ["main point 1", "main point 2", ...],
            "actionItems": [
                {"task": "specific action", "owner": "person name", "deadline": "date if mentioned", "priority": "high/medium/low"}
            ],
            "decisions": [
                {"decision": "what was decided", "context": "why/how", "impact": "consequences"}
            ],
            "questions": [
                {"question": "unresolved question", "assignedTo": "person/team", "urgency": "high/medium/low"}
            ],
            "risks": ["identified risk 1", "identified risk 2"],
            "followUp": ["item needing follow-up", ...]
        }
        
        Important:
        - Extract ALL action items mentioned
        - Identify decision makers when possible
        - Note any deadlines or time constraints
        - Flag critical items that need immediate attention
        - Return ONLY valid JSON, no markdown or explanation
        """
    }
}
```

## Phase 5: Memory Management

```swift
class LFM2Manager {
    func optimizeForDevice() async {
        // Check available memory
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        
        if availableMemory < 4_000_000_000 {  // Less than 4GB
            // Use quantized model
            leapModel?.setPrecision(.int8)
        }
        
        // Set memory limits
        leapModel?.setMaxMemoryUsage(2_000_000_000)  // 2GB limit
    }
    
    func handleMemoryPressure() {
        // Clear inference cache
        leapSession?.clearCache()
        
        // Reduce batch size
        leapSession?.setBatchSize(1)
    }
}
```

## Phase 6: Error Handling

```swift
func generate(prompt: String, configuration: ModelConfiguration) async throws -> String {
    do {
        guard let session = leapSession else {
            // Try to reload model
            try await loadModel()
            guard let session = leapSession else {
                throw LFM2Error.modelNotLoaded
            }
        }
        
        return try await session.generate(prompt: prompt, parameters: params)
        
    } catch LeapError.outOfMemory {
        // Handle memory pressure
        handleMemoryPressure()
        // Retry with smaller context
        let truncatedPrompt = String(prompt.prefix(2000))
        return try await generate(prompt: truncatedPrompt, configuration: configuration)
        
    } catch LeapError.timeout {
        // Retry with shorter max tokens
        var newConfig = configuration
        newConfig.maxTokens = min(256, configuration.maxTokens / 2)
        return try await generate(prompt: prompt, configuration: newConfig)
    }
}
```

## Implementation Steps

### Week 1
1. ✅ Remove all mock implementation code
2. ✅ Add Leap SDK dependency
3. ✅ Implement basic model loading with bundle

### Week 2  
1. ✅ Implement generate() with Leap SDK (no streaming)
2. ✅ Test single prompt analysis after recording ends
3. ✅ Create LFM2Prompts.swift file

### Week 3
1. ✅ Implement JSON generation
2. ✅ Add retry logic for JSON parsing
3. ✅ Optimize prompts for reliable structured output

### Week 4
1. ✅ Add memory management
2. ✅ Implement error handling
3. ✅ Performance optimization
4. ✅ Testing on real devices

## Testing Checklist

- [ ] Mock code completely removed
- [ ] Bundle loads without extraction
- [ ] Leap SDK initializes successfully
- [ ] Basic text generation works
- [ ] JSON responses parse correctly
- [ ] Memory stays under 2GB
- [ ] Handles errors gracefully
- [ ] Background processing works
- [ ] Performance meets targets (<30s per meeting hour)

## Success Metrics

- Model loads in <5 seconds
- Inference speed >10 tokens/second  
- JSON parsing success rate >95%
- Memory usage <2GB peak
- No crashes on iPhone 12 and newer

## References

- [Leap iOS Quick Start](https://leap.liquid.ai/docs/edge-sdk/ios/ios-quick-start-guide)
- [Leap API Documentation](https://leap.liquid.ai/docs/edge-sdk/ios/api-reference)
- Model: `LFM2-700M-8da4w_output_8da8w-seq_4096.bundle`