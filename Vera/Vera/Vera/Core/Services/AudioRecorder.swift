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
        print("🎵 [AudioRecorder] Setting up audio session")
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default)
            try audioSession?.setActive(true)
            print("✅ [AudioRecorder] Audio session configured")
            
            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                if allowed {
                    print("✅ [AudioRecorder] Microphone permission granted")
                } else {
                    print("❌ [AudioRecorder] Microphone permission denied")
                    self?.error = RecordingError.permissionDenied
                }
            }
        } catch {
            self.error = error
            print("❌ [AudioRecorder] Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        print("🎤 [AudioRecorder] startRecording called")
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        print("📁 [AudioRecorder] Recording to: \(audioFilename.lastPathComponent)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        print("⚙️ [AudioRecorder] Audio settings: 44.1kHz, Mono, AAC High Quality")
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            print(success ? "✅ [AudioRecorder] Recording started successfully" : "❌ [AudioRecorder] Failed to start recording")
            
            isRecording = true
            recordingTime = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.recordingTime += 1
            }
            
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateAudioLevel()
            }
            
            print("⏰ [AudioRecorder] Timers started")
        } catch {
            self.error = error
            print("❌ [AudioRecorder] Failed to create recorder: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() -> URL? {
        print("🛑 [AudioRecorder] stopRecording called")
        
        guard let recorder = audioRecorder else { 
            print("⚠️ [AudioRecorder] No active recorder")
            return nil 
        }
        
        let url = recorder.url
        print("📁 [AudioRecorder] Stopping recording: \(url.lastPathComponent)")
        print("⏱️ [AudioRecorder] Recording duration: \(recordingTime) seconds")
        
        recorder.stop()
        audioRecorder = nil
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
        
        // Check if file exists
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("✅ [AudioRecorder] Audio file saved: \(fileSize) bytes")
            } catch {
                print("⚠️ [AudioRecorder] Could not get file size: \(error)")
            }
        } else {
            print("❌ [AudioRecorder] Audio file not found at path")
        }
        
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
        print("🎤 [AudioRecorder] Recording finished - Success: \(flag)")
        if !flag {
            error = RecordingError.recordingFailed
            print("❌ [AudioRecorder] Recording failed")
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