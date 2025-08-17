import SwiftUI
import CoreData

struct SingleNoteView: View {
    @ObservedObject var meeting: Meeting
    @StateObject private var recordingService: MeetingRecordingService
    @State private var noteContent: String = ""
    @State private var noteTitle: String = ""
    @State private var isRecording = false
    @State private var isEnhancing = false
    @State private var showingShareSheet = false
    @State private var showingTranscript = false
    @FocusState private var isEditing: Bool
    @FocusState private var isTitleEditing: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    init(meeting: Meeting) {
        self.meeting = meeting
        let context = PersistenceController.shared.container.viewContext
        let service = MeetingRecordingService(context: context)
        service.currentMeeting = meeting
        _recordingService = StateObject(wrappedValue: service)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Note content editor
            TextEditor(text: $noteContent)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .focused($isEditing)
                .onChange(of: noteContent) { newValue in
                    saveNote()
                }
            
            // Recording indicator
            if recordingService.isRecording {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(.red)
                        .symbolEffect(.pulse)
                    Text("Recording: \(formatDuration(recordingService.recordingDuration))")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Bottom toolbar
            HStack(spacing: 20) {
                // Recording button
                Button(action: toggleRecording) {
                    Image(systemName: recordingService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title)
                        .foregroundColor(recordingService.isRecording ? .red : .blue)
                }
                
                
                Spacer()
                
                // Done button to dismiss keyboard
                if isEditing {
                    Button("Done") {
                        isEditing = false
                    }
                    .font(.body.bold())
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(UIColor.separator)),
                alignment: .top
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Meeting Title", text: $noteTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($isTitleEditing)
                    .onSubmit {
                        saveTitle()
                        isTitleEditing = false
                    }
                    .onTapGesture {
                        // When tapped, if it's the default title, select all for easy replacement
                        isTitleEditing = true
                        if noteTitle == "New Meeting" {
                            // Clear the field when user taps on default title
                            // This gives immediate visual feedback that they can type a new title
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                noteTitle = ""
                            }
                        }
                    }
                    .onChange(of: noteTitle) { newValue in
                        // Clear detection logic:
                        // If the title was "New Meeting" and user is deleting characters
                        // (newValue is "New Meetin", "New Meeti", etc.)
                        // then clear the whole field to save them time
                        if newValue.count > 0 && 
                           newValue.count < "New Meeting".count &&
                           "New Meeting".starts(with: newValue) {
                            // User is backspacing through "New Meeting", clear it all
                            noteTitle = ""
                        }
                    }
                    .frame(maxWidth: 250)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if let transcript = meeting.transcript, !transcript.isEmpty {
                        Button(action: { 
                            showingTranscript = true
                        }) {
                            Label("View Transcript", systemImage: "text.quote")
                        }
                    }
                    
                    Button(action: { 
                        enhanceWithAI()
                    }) {
                        Label("Reanalyze with AI", systemImage: "sparkles")
                    }
                    .disabled(isEnhancing)
                    
                    Button(action: { 
                        showingShareSheet = true 
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadNote()
            recordingService.currentMeeting = meeting
            
            // Auto-focus keyboard for new meetings
            if meeting.rawNotes?.isEmpty ?? true && 
               meeting.transcript?.isEmpty ?? true {
                isEditing = true
            }
        }
        .onDisappear {
            if recordingService.isRecording {
                recordingService.stopRecordingSession()
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            NoteShareSheet(content: generateShareContent())
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptView(meeting: meeting)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TranscriptUpdated"))) { _ in
            updateTranscript()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MeetingAnalysisCompleted"))) { notification in
            // Reload notes when LFM2 analysis completes
            if let meetingID = notification.userInfo?["meetingID"] as? UUID,
               meetingID == meeting.id {
                loadNote()
            }
        }
    }
    
    private func loadNote() {
        // Load title
        noteTitle = meeting.title ?? ""
        
        var content = ""
        
        // Load user notes
        if let notes = meeting.rawNotes, !notes.isEmpty {
            content = notes
        }
        
        // Add enhanced notes if available (but not transcript)
        if let enhanced = meeting.enhancedNotes, !enhanced.isEmpty {
            if !content.isEmpty {
                content += "\n\n--- AI Analysis ---\n"
            }
            content += enhanced
        }
        
        noteContent = content
    }
    
    private func saveNote() {
        // Save the raw content (before transcript/enhancement markers)
        let lines = noteContent.components(separatedBy: "\n--- ")
        meeting.rawNotes = lines.first ?? noteContent
        
        // Only auto-generate title if it's empty
        if noteTitle.isEmpty {
            meeting.title = generateTitle(from: meeting.rawNotes ?? "")
            noteTitle = meeting.title ?? "Untitled Meeting"
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save note: \(error)")
        }
    }
    
    private func saveTitle() {
        meeting.title = noteTitle.isEmpty ? "Untitled Meeting" : noteTitle
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save title: \(error)")
        }
    }
    
    private func generateTitle(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let title = String(firstLine.prefix(50))
            return title.isEmpty ? "Untitled Meeting" : title
        }
        return "Untitled Meeting"
    }
    
    private func toggleRecording() {
        if recordingService.isRecording {
            recordingService.stopRecordingSession()
            isRecording = false
            // Update transcript immediately with what we have
            updateTranscript()
            // Note: Enhancement happens automatically in MeetingRecordingService.processInBackground
        } else {
            recordingService.startRecordingSession()
            isRecording = true
        }
    }
    
    private func updateTranscript() {
        let transcript = recordingService.currentTranscript
        print("📋 [SingleNoteView] updateTranscript called with: '\(transcript)' (\(transcript.count) chars)")
        
        guard !transcript.isEmpty else { 
            print("⚠️ [SingleNoteView] Transcript is empty, skipping update")
            return 
        }
        
        // Save transcript to meeting model but don't add to note content
        meeting.transcript = transcript
        print("💾 [SingleNoteView] Saving transcript to meeting: '\(transcript)' (\(transcript.count) chars)")
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save transcript: \(error)")
        }
        
        // Analysis is handled by MeetingRecordingService when stopping recording
        // Don't trigger it here to avoid conflicts
    }
    
    private func enhanceWithAI() {
        isEnhancing = true
        
        Task {
            let enhancementService = MeetingEnhancementService.shared
            do {
                try await enhancementService.analyzeCompletedMeeting(meeting, context: viewContext)
                
                await MainActor.run {
                    loadNote() // Reload to show enhanced content
                    isEnhancing = false
                }
            } catch {
                await MainActor.run {
                    print("Enhancement failed: \(error)")
                    isEnhancing = false
                }
            }
        }
    }
    
    private func generateShareContent() -> String {
        var content = meeting.title ?? "Meeting"
        content += "\n\n"
        content += noteContent
        content += "\n\n---\nGenerated by Vera"
        return content
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct NoteShareSheet: UIViewControllerRepresentable {
    let content: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}