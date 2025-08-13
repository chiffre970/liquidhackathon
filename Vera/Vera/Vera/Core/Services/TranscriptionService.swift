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
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .denied, .restricted:
                    self?.error = TranscriptionError.authorizationDenied
                case .notDetermined:
                    self?.error = TranscriptionError.notDetermined
                default:
                    break
                }
            }
        }
    }
    
    func startTranscribing() {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            error = TranscriptionError.recognizerNotAvailable
            return
        }
        
        do {
            try startAudioEngine()
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                error = TranscriptionError.requestCreationFailed
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self?.transcribedText = result.bestTranscription.formattedString
                    }
                }
                
                if error != nil || result?.isFinal == true {
                    self?.stopTranscribing()
                }
            }
            
            isTranscribing = true
        } catch {
            self.error = error
        }
    }
    
    func stopTranscribing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isTranscribing = false
    }
    
    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func transcribeAudioFile(at url: URL) async -> String? {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            error = TranscriptionError.recognizerNotAvailable
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true
            
            speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    self.error = error
                    continuation.resume(returning: nil)
                } else if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
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