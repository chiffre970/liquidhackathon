import Foundation
import AVFoundation
import CoreData
import Combine

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
    
    private let context = PersistenceController.shared.container.viewContext
    private var cancellables = Set<AnyCancellable>()
    
    init() {
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
        let meeting = Meeting(context: context)
        meeting.id = UUID()
        meeting.title = title ?? generateMeetingTitle()
        meeting.date = Date()
        meeting.duration = 0
        meeting.templateUsed = template
        meeting.rawNotes = ""
        
        do {
            try context.save()
            currentMeeting = meeting
        } catch {
            self.error = error
            print("Failed to create meeting: \(error)")
        }
        
        startRecording()
        
        return meeting
    }
    
    func stopMeeting() {
        stopRecording()
        
        if let meeting = currentMeeting {
            meeting.duration = recordingDuration
            
            if let finalAudioURL = mergeAudioChunks() {
                meeting.audioFileURL = finalAudioURL.absoluteString
            }
            
            do {
                try context.save()
                processInBackground(meeting: meeting)
            } catch {
                self.error = error
                print("Failed to save meeting: \(error)")
            }
        }
        
        cleanup()
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
        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        recordingDuration = 0
        pausedDuration = 0
        audioChunks = []
        
        audioRecorder.startRecording()
        transcriptionService.startTranscribing()
        
        startTimers()
    }
    
    private func stopRecording() {
        isRecording = false
        isPaused = false
        
        if let currentChunkURL = audioRecorder.stopRecording() {
            audioChunks.append(currentChunkURL)
        }
        
        transcriptionService.stopTranscribing()
        
        timer?.invalidate()
        chunkTimer?.invalidate()
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
        guard isRecording && !isPaused else { return }
        
        if let currentChunkURL = audioRecorder.stopRecording() {
            audioChunks.append(currentChunkURL)
            
            audioRecorder.startRecording()
            
            Task {
                if let transcription = await transcriptionService.transcribeAudioFile(at: currentChunkURL) {
                    await MainActor.run {
                        self.currentTranscript += "\n" + transcription
                    }
                }
            }
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
        guard let meeting = currentMeeting else { return }
        
        meeting.rawNotes = notes
        
        do {
            try context.save()
        } catch {
            self.error = error
            print("Failed to update notes: \(error)")
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