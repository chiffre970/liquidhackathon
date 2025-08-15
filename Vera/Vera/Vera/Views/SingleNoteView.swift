import SwiftUI
import CoreData

struct SingleNoteView: View {
    @ObservedObject var meeting: Meeting
    @StateObject private var recordingService: MeetingRecordingService
    @State private var noteContent: String = ""
    @State private var noteTitle: String = ""
    @State private var isRecording = false
    @State private var showingEnhanceAlert = false
    @State private var isEnhancing = false
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
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
                RecordingIndicatorView(
                    duration: recordingService.recordingDuration,
                    isPaused: recordingService.isPaused
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // Bottom toolbar
            HStack(spacing: 20) {
                // Recording button
                Button(action: toggleRecording) {
                    Image(systemName: recordingService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title)
                        .foregroundColor(recordingService.isRecording ? .red : .blue)
                }
                
                if recordingService.isRecording {
                    Button(action: togglePause) {
                        Image(systemName: recordingService.isPaused ? "play.circle" : "pause.circle")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // AI Enhance button (only show if there's content)
                if !noteContent.isEmpty || meeting.transcript != nil {
                    Button(action: { showingEnhanceAlert = true }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Enhance")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isEnhancing)
                }
                
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
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
                TextField("Note Title", text: $noteTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($isTitleEditing)
                    .onSubmit {
                        saveTitle()
                        isTitleEditing = false
                    }
                    .onTapGesture {
                        isTitleEditing = true
                    }
                    .frame(maxWidth: 250)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingDeleteAlert = true }) {
                        Label("Delete Note", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadNote()
            recordingService.currentMeeting = meeting
        }
        .onDisappear {
            if recordingService.isRecording {
                recordingService.stopRecordingSession()
            }
        }
        .alert("Enhance with AI?", isPresented: $showingEnhanceAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Enhance") {
                enhanceWithAI()
            }
        } message: {
            Text("This will use AI to create a structured summary and extract key insights from your note.")
        }
        .alert("Delete Note?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            NoteShareSheet(content: generateShareContent())
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TranscriptUpdated"))) { _ in
            updateTranscript()
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
        
        // Add transcript if available
        if let transcript = meeting.transcript, !transcript.isEmpty {
            if !content.isEmpty {
                content += "\n\n--- Transcript ---\n"
            }
            content += transcript
        }
        
        // Add enhanced notes if available
        if let enhanced = meeting.enhancedNotes, !enhanced.isEmpty {
            if !content.isEmpty {
                content += "\n\n--- AI Summary ---\n"
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
            noteTitle = meeting.title ?? "Untitled Note"
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save note: \(error)")
        }
    }
    
    private func saveTitle() {
        meeting.title = noteTitle.isEmpty ? "Untitled Note" : noteTitle
        
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
            return title.isEmpty ? "Untitled Note" : title
        }
        return "Untitled Note"
    }
    
    private func toggleRecording() {
        if recordingService.isRecording {
            recordingService.stopRecordingSession()
            isRecording = false
            // Update the note content with the transcript
            updateTranscript()
        } else {
            recordingService.startRecordingSession()
            isRecording = true
        }
    }
    
    private func togglePause() {
        if recordingService.isPaused {
            recordingService.resumeRecording()
        } else {
            recordingService.pauseRecording()
        }
    }
    
    private func updateTranscript() {
        let transcript = recordingService.currentTranscript
        guard !transcript.isEmpty else { return }
        
        // Remove any existing transcript section
        let lines = noteContent.components(separatedBy: "\n--- Transcript ---\n")
        var baseContent = lines.first ?? noteContent
        
        // Add the new transcript
        if !baseContent.isEmpty {
            baseContent += "\n\n"
        }
        baseContent += "--- Transcript ---\n" + transcript
        
        noteContent = baseContent
        meeting.transcript = transcript
        saveNote()
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
    
    private func deleteNote() {
        viewContext.delete(meeting)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to delete note: \(error)")
        }
    }
    
    private func generateShareContent() -> String {
        var content = meeting.title ?? "Note"
        content += "\n\n"
        content += noteContent
        content += "\n\n---\nGenerated by Vera"
        return content
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