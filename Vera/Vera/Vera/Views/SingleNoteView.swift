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
    @State private var isEditingMode = false
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
        ZStack {
            // Background with inner shadow
            Color.primaryBackground
                .ignoresSafeArea()
                .overlay(
                    // Inner shadow from all edges
                    Rectangle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.clear, location: 0.0),
                                    .init(color: Color.clear, location: 0.7),
                                    .init(color: Color(hex: "#4A90E2").opacity(0.01), location: 0.85),
                                    .init(color: Color(hex: "#4A90E2").opacity(0.03), location: 1.0)
                                ]),
                                center: .center,
                                startRadius: 150,
                                endRadius: 400
                            )
                        )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                )
                .overlay(
                    // Additional edge highlight - uniform on all sides
                    RoundedRectangle(cornerRadius: 0)
                        .strokeBorder(
                            Color(hex: "#4A90E2").opacity(0.025),
                            lineWidth: 20
                        )
                        .blur(radius: 15)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                )
            
            VStack(spacing: 0) {
            // Note content - show markdown rendered or editor
            if isEditingMode {
                TextEditor(text: $noteContent)
                    .foregroundColor(.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .focused($isEditing)
                    .onChange(of: noteContent) { newValue in
                        saveNote()
                    }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let attributedString = try? AttributedString(markdown: noteContent, 
                                                                        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(attributedString)
                                .foregroundColor(.primaryText)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(noteContent)
                                .foregroundColor(.primaryText)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .onTapGesture {
                    isEditingMode = true
                    isEditing = true
                }
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
            }
            .overlay(
            // Floating Record Button
            VStack {
                Spacer()
                
                FloatingActionButton(
                    title: recordingService.isRecording ? "Stop Recording" : "Start Recording",
                    icon: recordingService.isRecording ? "stop.circle.fill" : "mic.circle.fill",
                    action: toggleRecording,
                    isActive: recordingService.isRecording,
                    showTitle: true
                )
                .padding(.bottom, 30)
            }
        )
        .overlay(
            // Done button overlay when editing
            VStack {
                HStack {
                    Spacer()
                    if isEditingMode {
                        Button("Done") {
                            isEditing = false
                            isEditingMode = false
                        }
                        .font(.body.bold())
                        .foregroundColor(.blue)
                        .padding()
                    }
                }
                Spacer()
            }
        )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Meeting Title", text: $noteTitle)
                    .font(.headline)
                    .foregroundColor(.primaryText)
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
                        } else {
                            // Save title immediately on every change
                            saveTitle()
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
            
            // Don't auto-focus keyboard
            isEditingMode = false
            isEditing = false
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
        noteTitle = meeting.title
        
        var content = ""
        
        // Load user notes if available
        if let notes = meeting.rawNotes, !notes.isEmpty {
            content = notes
        }
        
        // Show enhanced notes if available (replaces content if no user notes)
        if let enhanced = meeting.enhancedNotes, !enhanced.isEmpty {
            // If there are user notes, append the AI summary
            if !content.isEmpty {
                content += "\n\n"
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
            noteTitle = meeting.title.isEmpty ? "Untitled Meeting" : meeting.title
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save note: \(error)")
        }
    }
    
    private func saveTitle() {
        meeting.title = noteTitle.isEmpty ? "Untitled Meeting" : noteTitle
        
        // Trigger immediate update
        meeting.objectWillChange.send()
        
        do {
            try viewContext.save()
            // Force refresh of the fetch request
            viewContext.refresh(meeting, mergeChanges: true)
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
        var content = meeting.title.isEmpty ? "Meeting" : meeting.title
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
