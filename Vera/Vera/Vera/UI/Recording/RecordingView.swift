import SwiftUI

struct RecordingView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriptionService = TranscriptionService()
    @State private var showTranscription = false
    @State private var lastRecordingURL: URL?
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                ParticleOrbView(
                    isRecording: $audioRecorder.isRecording,
                    audioLevel: audioRecorder.audioLevel
                )
                .onTapGesture {
                    handleOrbTap()
                }
                
                if audioRecorder.isRecording {
                    VStack(spacing: 12) {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.gray.opacity(0.6))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(audioRecorder.isRecording ? 1.2 : 1.0)
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.2),
                                        value: audioRecorder.isRecording
                                    )
                            }
                        }
                        
                        Text("Recording...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text(formatTime(audioRecorder.recordingTime))
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                
                Spacer()
                
                if showTranscription && !transcriptionService.transcribedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        ScrollView {
                            Text(transcriptionService.transcribedText)
                                .font(.system(size: 14))
                                .foregroundColor(.black.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 100)
                        .padding(12)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, 40)
        }
        .alert("Error", isPresented: .constant(audioRecorder.error != nil || transcriptionService.error != nil)) {
            Button("OK") {
                audioRecorder.error = nil
                transcriptionService.error = nil
            }
        } message: {
            Text(audioRecorder.error?.localizedDescription ?? transcriptionService.error?.localizedDescription ?? "")
        }
    }
    
    private func handleOrbTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if audioRecorder.isRecording {
            if let url = audioRecorder.stopRecording() {
                lastRecordingURL = url
                transcriptionService.stopTranscribing()
                processRecording(at: url)
            }
        } else {
            audioRecorder.startRecording()
            transcriptionService.startTranscribing()
            showTranscription = true
        }
    }
    
    private func processRecording(at url: URL) {
        Task {
            if let transcription = await transcriptionService.transcribeAudioFile(at: url) {
                await processWithLFM2(transcription: transcription, audioURL: url)
            }
        }
    }
    
    private func processWithLFM2(transcription: String, audioURL: URL) async {
        await BackgroundProcessor.shared.processThought(
            transcription: transcription,
            audioURL: audioURL
        )
        
        withAnimation {
            showTranscription = false
            transcriptionService.transcribedText = ""
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}