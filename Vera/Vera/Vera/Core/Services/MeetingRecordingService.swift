import Foundation
import AVFoundation
import CoreData
import Combine
import SwiftUI

class MeetingRecordingService: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentTranscript: String = ""
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentMeeting: Meeting?
    @Published var error: Error?
    
    private var audioRecorder: AudioRecorder
    private var transcriptionService: TranscriptionService
    private var timer: Timer?
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseTime: Date?
    
    private var audioChunks: [URL] = []
    private var chunkTimer: Timer?
    private let chunkInterval: TimeInterval = 30
    
    private var context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext? = nil) {
        self.context = context ?? PersistenceController.shared.container.viewContext
        self.audioRecorder = AudioRecorder()
        self.transcriptionService = TranscriptionService()
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        transcriptionService.$transcribedText
            .sink { [weak self] text in
                self?.currentTranscript = text
            }
            .store(in: &cancellables)
        
        audioRecorder.$audioLevel
            .sink { [weak self] _ in
            }
            .store(in: &cancellables)
    }
    
    func startMeeting(title: String? = nil, template: String? = nil) -> Meeting {
        print("📝 [MeetingRecordingService] startMeeting called - title: \(title ?? "nil"), template: \(template ?? "nil")")
        
        let meeting = Meeting(context: context)
        meeting.id = UUID()
        meeting.title = title ?? generateMeetingTitle()
        meeting.date = Date()
        meeting.duration = 0
        meeting.templateUsed = template
        meeting.rawNotes = ""
        
        print("📝 [MeetingRecordingService] Created meeting with ID: \(meeting.id), title: \(meeting.title)")
        
        do {
            try context.save()
            currentMeeting = meeting
            print("✅ [MeetingRecordingService] Meeting saved to CoreData successfully")
        } catch {
            self.error = error
            print("❌ [MeetingRecordingService] Failed to create meeting: \(error)")
        }
        
        print("🎙️ [MeetingRecordingService] Starting recording...")
        startRecording()
        
        return meeting
    }
    
    func stopMeeting() {
        print("🛑 [MeetingRecordingService] stopMeeting called")
        print("📊 [MeetingRecordingService] Current meeting ID: \(currentMeeting?.id.uuidString ?? "nil")")
        print("⏱️ [MeetingRecordingService] Recording duration: \(recordingDuration) seconds")
        
        stopRecording()
        
        if let meeting = currentMeeting {
            meeting.duration = recordingDuration
            meeting.transcript = currentTranscript
            print("📝 [MeetingRecordingService] Updated meeting duration: \(meeting.duration)")
            print("📝 [MeetingRecordingService] Saved transcript: \(currentTranscript.count) characters")
            
            if let finalAudioURL = mergeAudioChunks() {
                meeting.audioFileURL = finalAudioURL.absoluteString
                print("🎵 [MeetingRecordingService] Audio saved to: \(finalAudioURL.lastPathComponent)")
            } else {
                print("⚠️ [MeetingRecordingService] No audio URL created")
            }
            
            do {
                try context.save()
                print("✅ [MeetingRecordingService] Meeting saved successfully")
                processInBackground(meeting: meeting)
            } catch {
                self.error = error
                print("❌ [MeetingRecordingService] Failed to save meeting: \(error)")
            }
        } else {
            print("⚠️ [MeetingRecordingService] No current meeting to stop")
        }
        
        cleanup()
        print("🧹 [MeetingRecordingService] Cleanup completed")
    }
    
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        isPaused = true
        lastPauseTime = Date()
        
        if let currentChunkURL = audioRecorder.stopRecording() {
            audioChunks.append(currentChunkURL)
        }
        
        transcriptionService.stopTranscribing()
        
        timer?.invalidate()
        chunkTimer?.invalidate()
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        if let pauseTime = lastPauseTime {
            pausedDuration += Date().timeIntervalSince(pauseTime)
        }
        
        isPaused = false
        lastPauseTime = nil
        
        audioRecorder.startRecording()
        transcriptionService.startTranscribing()
        
        startTimers()
    }
    
    private func startRecording() {
        print("🎙️ [MeetingRecordingService] startRecording called")
        
        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        recordingDuration = 0
        pausedDuration = 0
        audioChunks = []
        
        print("🎤 [MeetingRecordingService] Starting audio recorder...")
        audioRecorder.startRecording()
        
        print("🗣️ [MeetingRecordingService] Starting transcription service...")
        transcriptionService.startTranscribing()
        
        print("⏰ [MeetingRecordingService] Starting timers...")
        startTimers()
        
        print("✅ [MeetingRecordingService] Recording started successfully")
    }
    
    private func stopRecording() {
        print("🛑 [MeetingRecordingService] stopRecording called")
        
        isRecording = false
        isPaused = false
        
        print("🎤 [MeetingRecordingService] Stopping audio recorder...")
        if let currentChunkURL = audioRecorder.stopRecording() {
            audioChunks.append(currentChunkURL)
            print("📁 [MeetingRecordingService] Added final chunk: \(currentChunkURL.lastPathComponent)")
        }
        
        print("🗣️ [MeetingRecordingService] Stopping transcription...")
        transcriptionService.stopTranscribing()
        
        print("⏰ [MeetingRecordingService] Invalidating timers...")
        timer?.invalidate()
        chunkTimer?.invalidate()
        
        print("📊 [MeetingRecordingService] Total chunks collected: \(audioChunks.count)")
        print("📝 [MeetingRecordingService] Final transcript length: \(currentTranscript.count) characters")
    }
    
    private func startTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            
            if !self.isPaused {
                self.recordingDuration = Date().timeIntervalSince(startTime) - self.pausedDuration
            }
        }
        
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkInterval, repeats: true) { [weak self] _ in
            self?.saveAudioChunk()
        }
    }
    
    private func saveAudioChunk() {
        guard isRecording && !isPaused else { 
            print("⏸️ [MeetingRecordingService] Skipping chunk save - not recording or paused")
            return 
        }
        
        print("💾 [MeetingRecordingService] Saving audio chunk #\(audioChunks.count + 1)")
        
        if let currentChunkURL = audioRecorder.stopRecording() {
            audioChunks.append(currentChunkURL)
            print("✅ [MeetingRecordingService] Chunk saved: \(currentChunkURL.lastPathComponent)")
            
            print("🎤 [MeetingRecordingService] Restarting audio recorder for next chunk...")
            audioRecorder.startRecording()
            
            Task {
                print("🔄 [MeetingRecordingService] Transcribing chunk...")
                if let transcription = await transcriptionService.transcribeAudioFile(at: currentChunkURL) {
                    await MainActor.run {
                        let previousLength = self.currentTranscript.count
                        self.currentTranscript += "\n" + transcription
                        print("📝 [MeetingRecordingService] Added \(transcription.count) chars to transcript (total: \(self.currentTranscript.count))")
                    }
                } else {
                    print("⚠️ [MeetingRecordingService] Failed to transcribe chunk")
                }
            }
        } else {
            print("❌ [MeetingRecordingService] Failed to save audio chunk")
        }
    }
    
    private func mergeAudioChunks() -> URL? {
        guard !audioChunks.isEmpty else { return nil }
        
        if audioChunks.count == 1 {
            return audioChunks[0]
        }
        
        let composition = AVMutableComposition()
        let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        var currentTime = CMTime.zero
        
        for chunkURL in audioChunks {
            let asset = AVAsset(url: chunkURL)
            guard let track = asset.tracks(withMediaType: .audio).first else { continue }
            
            let duration = asset.duration
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            try? compositionTrack?.insertTimeRange(
                timeRange,
                of: track,
                at: currentTime
            )
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("meeting_\(UUID().uuidString).m4a")
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else { return nil }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        let semaphore = DispatchSemaphore(value: 0)
        
        exportSession.exportAsynchronously {
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if exportSession.status == .completed {
            cleanupAudioChunks()
            return outputURL
        }
        
        return nil
    }
    
    private func cleanupAudioChunks() {
        for chunkURL in audioChunks {
            try? FileManager.default.removeItem(at: chunkURL)
        }
        audioChunks = []
    }
    
    private func processInBackground(meeting: Meeting) {
        Task {
            if !currentTranscript.isEmpty {
                meeting.transcript = currentTranscript
            }
            
            if let audioURLString = meeting.audioFileURL,
               let audioURL = URL(string: audioURLString) {
                if let fullTranscription = await transcriptionService.transcribeAudioFile(at: audioURL) {
                    meeting.transcript = fullTranscription
                }
            }
            
            await enhanceMeetingWithLFM2(meeting: meeting)
            
            await MainActor.run {
                do {
                    try context.save()
                } catch {
                    self.error = error
                    print("Failed to save enhanced meeting: \(error)")
                }
            }
        }
    }
    
    private func enhanceMeetingWithLFM2(meeting: Meeting) async {
    }
    
    private func generateMeetingTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Meeting - \(formatter.string(from: Date()))"
    }
    
    private func cleanup() {
        currentMeeting = nil
        currentTranscript = ""
        recordingDuration = 0
        recordingStartTime = nil
        pausedDuration = 0
        lastPauseTime = nil
        cleanupAudioChunks()
    }
    
    func updateNotes(_ notes: String) {
        guard let meeting = currentMeeting else { 
            print("⚠️ [MeetingRecordingService] updateNotes - No current meeting")
            return 
        }
        
        print("📝 [MeetingRecordingService] Updating notes for meeting \(meeting.id.uuidString)")
        print("📏 [MeetingRecordingService] Notes length: \(notes.count) characters")
        
        meeting.rawNotes = notes
        
        do {
            try context.save()
            print("✅ [MeetingRecordingService] Notes updated successfully")
        } catch {
            self.error = error
            print("❌ [MeetingRecordingService] Failed to update notes: \(error)")
        }
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        if let audioURLString = meeting.audioFileURL,
           let audioURL = URL(string: audioURLString) {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        context.delete(meeting)
        
        do {
            try context.save()
        } catch {
            self.error = error
            print("Failed to delete meeting: \(error)")
        }
    }
}

extension MeetingRecordingService {
    static func fetchAllMeetings(context: NSManagedObjectContext) -> [Meeting] {
        let request: NSFetchRequest<Meeting> = Meeting.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Meeting.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch meetings: \(error)")
            return []
        }
    }
    
    static func searchMeetings(query: String, context: NSManagedObjectContext) -> [Meeting] {
        let request: NSFetchRequest<Meeting> = Meeting.fetchRequest()
        
        let predicates = [
            NSPredicate(format: "title CONTAINS[cd] %@", query),
            NSPredicate(format: "rawNotes CONTAINS[cd] %@", query),
            NSPredicate(format: "transcript CONTAINS[cd] %@", query),
            NSPredicate(format: "enhancedNotes CONTAINS[cd] %@", query)
        ]
        
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Meeting.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to search meetings: \(error)")
            return []
        }
    }
}