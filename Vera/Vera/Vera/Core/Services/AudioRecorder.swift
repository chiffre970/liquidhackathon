import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingTime: TimeInterval = 0
    @Published var error: Error?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private var timer: Timer?
    private var levelTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default)
            try audioSession?.setActive(true)
            
            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                if !allowed {
                    self?.error = RecordingError.permissionDenied
                }
            }
        } catch {
            self.error = error
        }
    }
    
    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.recordingTime += 1
            }
            
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateAudioLevel()
            }
        } catch {
            self.error = error
        }
    }
    
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder else { return nil }
        
        let url = recorder.url
        recorder.stop()
        audioRecorder = nil
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
        
        return url
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        let normalizedLevel = pow(10, level / 20)
        
        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            error = RecordingError.recordingFailed
        }
    }
}

enum RecordingError: LocalizedError {
    case permissionDenied
    case recordingFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied. Please enable in Settings."
        case .recordingFailed:
            return "Recording failed. Please try again."
        }
    }
}