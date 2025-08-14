import Speech
import AVFoundation

class TranscriptionService: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var error: Error?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        print("🔐 [TranscriptionService] Requesting speech recognition authorization")
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ [TranscriptionService] Speech recognition authorized")
                case .denied:
                    print("❌ [TranscriptionService] Speech recognition denied")
                    self?.error = TranscriptionError.authorizationDenied
                case .restricted:
                    print("🚫 [TranscriptionService] Speech recognition restricted")
                    self?.error = TranscriptionError.authorizationDenied
                case .notDetermined:
                    print("❓ [TranscriptionService] Speech recognition not determined")
                    self?.error = TranscriptionError.notDetermined
                @unknown default:
                    print("⚠️ [TranscriptionService] Unknown authorization status")
                }
            }
        }
    }
    
    func startTranscribing() {
        print("🗣️ [TranscriptionService] startTranscribing called")
        
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            print("❌ [TranscriptionService] Speech recognizer not available")
            error = TranscriptionError.recognizerNotAvailable
            return
        }
        
        print("🌐 [TranscriptionService] Using locale: \(speechRecognizer.locale.identifier)")
        
        do {
            print("🎵 [TranscriptionService] Starting audio engine...")
            try startAudioEngine()
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                print("❌ [TranscriptionService] Failed to create recognition request")
                error = TranscriptionError.requestCreationFailed
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true
            print("⚙️ [TranscriptionService] Request configured: partial results=true, on-device=true")
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    print("📣 [TranscriptionService] Transcribed: \(text.suffix(50))... (\(text.count) chars total)")
                    DispatchQueue.main.async {
                        self?.transcribedText = text
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    print("⚠️ [TranscriptionService] Recognition error: Code=\(nsError.code), \(error.localizedDescription)")
                    // Don't stop on error 1101, it's a warning that can be ignored
                    if nsError.code != 1101 {
                        print("🛑 [TranscriptionService] Stopping due to error")
                        self?.stopTranscribing()
                    }
                } else if result?.isFinal == true {
                    print("✅ [TranscriptionService] Recognition final result received")
                    self?.stopTranscribing()
                }
            }
            
            isTranscribing = true
            print("✅ [TranscriptionService] Transcription started successfully")
        } catch {
            self.error = error
            print("❌ [TranscriptionService] Failed to start: \(error.localizedDescription)")
        }
    }
    
    func stopTranscribing() {
        print("🛑 [TranscriptionService] stopTranscribing called")
        
        print("🎵 [TranscriptionService] Stopping audio engine")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        print("📤 [TranscriptionService] Ending recognition request")
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isTranscribing = false
        print("✅ [TranscriptionService] Transcription stopped")
        print("📝 [TranscriptionService] Final transcript length: \(transcribedText.count) characters")
    }
    
    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        print("🎵 [TranscriptionService] Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        print("✅ [TranscriptionService] Audio engine started")
    }
    
    func transcribeAudioFile(at url: URL) async -> String? {
        print("📁 [TranscriptionService] Transcribing file: \(url.lastPathComponent)")
        
        // Ensure any previous tasks are cleaned up
        if recognitionTask != nil {
            print("🧹 [TranscriptionService] Cleaning up previous recognition task")
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            
            // Wait a moment for cleanup
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            print("❌ [TranscriptionService] Speech recognizer not available for file transcription")
            error = TranscriptionError.recognizerNotAvailable
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true
            
            print("🔄 [TranscriptionService] Starting file recognition task...")
            let fileRecognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    let nsError = error as NSError
                    // Ignore error 1101 which is just a warning
                    if nsError.code == 1101 {
                        print("⚠️ [TranscriptionService] Ignoring error 1101 warning")
                        if let result = result {
                            let text = result.bestTranscription.formattedString
                            print("✅ [TranscriptionService] File transcribed despite warning: \(text.count) characters")
                            continuation.resume(returning: text)
                        }
                    } else {
                        print("❌ [TranscriptionService] File transcription error: \(error.localizedDescription)")
                        self.error = error
                        continuation.resume(returning: nil)
                    }
                } else if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    print("✅ [TranscriptionService] File transcribed: \(text.count) characters")
                    continuation.resume(returning: text)
                }
            }
            
            // Store reference if needed for cancellation
            print("📌 [TranscriptionService] File recognition task started")
        }
    }
}

enum TranscriptionError: LocalizedError {
    case authorizationDenied
    case notDetermined
    case recognizerNotAvailable
    case requestCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        case .notDetermined:
            return "Speech recognition not yet authorized"
        case .recognizerNotAvailable:
            return "Speech recognizer not available"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        }
    }
}