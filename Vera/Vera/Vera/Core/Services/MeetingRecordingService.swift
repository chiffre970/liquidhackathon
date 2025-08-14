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
            
            // Clean up temporary audio chunks without saving
            cleanupAudioChunks()
            print("🧙 [MeetingRecordingService] Temporary audio files cleaned up")
            
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
        
        print("💾 [MeetingRecordingService] Processing audio chunk #\(audioChunks.count + 1)")
        
        if let currentChunkURL = audioRecorder.stopRecording() {
            audioChunks.append(currentChunkURL)
            print("✅ [MeetingRecordingService] Chunk ready for transcription: \(currentChunkURL.lastPathComponent)")
            
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
                }
                
                // Delete the temporary audio chunk after transcription
                try? FileManager.default.removeItem(at: currentChunkURL)
                print("🧙 [MeetingRecordingService] Deleted temporary chunk: \(currentChunkURL.lastPathComponent)")
            }
        } else {
            print("❌ [MeetingRecordingService] Failed to process audio chunk")
        }
    }
    
    // This method is no longer needed as we don't save audio files
    
    private func cleanupAudioChunks() {
        for chunkURL in audioChunks {
            try? FileManager.default.removeItem(at: chunkURL)
        }
        audioChunks = []
    }
    
    private func processInBackground(meeting: Meeting) {
        Task {
            print("🔄 [MeetingRecordingService] Starting background processing for meeting: \(meeting.id)")
            
            if !currentTranscript.isEmpty {
                meeting.transcript = currentTranscript
            }
            
            // No audio file to transcribe since we only save the transcript
            
            meeting.processingStatus = ProcessingStatus.pending.rawValue
            
            await MainActor.run {
                do {
                    try context.save()
                } catch {
                    self.error = error
                    print("❌ Failed to save meeting before enhancement: \(error)")
                }
            }
            
            await enhanceMeetingWithLFM2(meeting: meeting)
            
            await MainActor.run {
                do {
                    try context.save()
                    print("✅ [MeetingRecordingService] Enhanced meeting saved successfully")
                    
                    NotificationCenter.default.post(
                        name: Notification.Name("MeetingEnhancementCompleted"),
                        object: meeting.id
                    )
                } catch {
                    self.error = error
                    print("❌ Failed to save enhanced meeting: \(error)")
                }
            }
        }
    }
    
    private func enhanceMeetingWithLFM2(meeting: Meeting) async {
        print("🤖 [MeetingRecordingService] Starting LFM2 analysis (single comprehensive prompt)...")
        
        let enhancementService = MeetingEnhancementService.shared
        
        do {
            // Use the new single comprehensive analysis method
            try await enhancementService.analyzeCompletedMeeting(meeting, context: context)
            print("✅ [MeetingRecordingService] LFM2 analysis completed successfully")
        } catch {
            print("❌ [MeetingRecordingService] LFM2 analysis failed: \(error)")
            meeting.processingStatus = ProcessingStatus.failed.rawValue
        }
    }
    
    private func generateMeetingTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Meeting - \(formatter.string(from: Date()))"
    }
    
    private func cleanup() {
        // Don't clear currentMeeting or transcript - keep them for display
        // currentMeeting = nil  // Removed to keep meeting visible
        // currentTranscript = ""  // Keep transcript visible after recording
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
        // No audio files to delete since we only save transcripts
        
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
    func createNewMeeting() {
        print("🆕 [MeetingRecordingService] Creating new meeting")
        
        // Clear transcript when starting a new meeting
        currentTranscript = ""
        
        let meeting = Meeting(context: context)
        meeting.id = UUID()
        meeting.title = generateMeetingTitle()
        meeting.date = Date()
        meeting.duration = 0
        meeting.rawNotes = ""
        
        do {
            try context.save()
            currentMeeting = meeting
            print("✅ [MeetingRecordingService] New meeting created with ID: \(meeting.id)")
        } catch {
            self.error = error
            print("❌ [MeetingRecordingService] Failed to create new meeting: \(error)")
        }
    }
    
    func saveMeeting() {
        guard let meeting = currentMeeting else { return }
        
        print("💾 [MeetingRecordingService] Saving meeting: \(meeting.id)")
        
        do {
            try context.save()
            print("✅ [MeetingRecordingService] Meeting saved")
        } catch {
            self.error = error
            print("❌ [MeetingRecordingService] Failed to save meeting: \(error)")
        }
    }
    
    func updateTitle(_ title: String) {
        guard let meeting = currentMeeting else {
            print("⚠️ [MeetingRecordingService] updateTitle - No current meeting")
            return
        }
        
        meeting.title = title.isEmpty ? generateMeetingTitle() : title
        
        do {
            try context.save()
            print("✅ [MeetingRecordingService] Title updated to: \(meeting.title)")
        } catch {
            self.error = error
            print("❌ [MeetingRecordingService] Failed to update title: \(error)")
        }
    }
    
    func updateTemplate(_ template: String) {
        guard let meeting = currentMeeting else {
            print("⚠️ [MeetingRecordingService] updateTemplate - No current meeting")
            return
        }
        
        meeting.templateUsed = template
        
        do {
            try context.save()
            print("✅ [MeetingRecordingService] Template updated to: \(template)")
        } catch {
            self.error = error
            print("❌ [MeetingRecordingService] Failed to update template: \(error)")
        }
    }
    
    func startRecordingSession() {
        print("🎙️ [MeetingRecordingService] Public startRecordingSession called")
        
        // Ensure we have a current meeting
        if currentMeeting == nil {
            createNewMeeting()
        }
        
        // Save any existing notes before starting
        saveMeeting()
        
        // Now start the actual recording
        startRecording()
    }
    
    func stopRecordingSession() {
        print("🛑 [MeetingRecordingService] Public stopRecordingSession called")
        stopMeeting()
    }
    

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