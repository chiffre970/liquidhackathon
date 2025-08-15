import SwiftUI
import CoreData

struct MeetingView: View {
    @StateObject private var recordingService: MeetingRecordingService
    @State private var userNotes: String = ""
    @State private var showTemplates = false
    @State private var selectedTemplate: String?
    @State private var meetingTitle: String = ""
    @State private var showEndMeetingAlert = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showNewMeetingAlert = false
    @FocusState private var isNotesFocused: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _recordingService = StateObject(wrappedValue: MeetingRecordingService(context: context))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if recordingService.isRecording {
                        RecordingIndicatorView(
                            duration: recordingService.recordingDuration
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    NoteEditorView(
                        text: $userNotes,
                        isRecording: recordingService.isRecording,
                        transcript: recordingService.currentTranscript.isEmpty ? nil : recordingService.currentTranscript,
                        onTextChange: { text in
                            print("📝 [MeetingView] Notes changed - length: \(text.count)")
                            recordingService.updateNotes(text)
                        }
                    )
                    .focused($isNotesFocused)
                    .padding(.top, recordingService.isRecording ? 8 : 0)
                    
                    if !recordingService.isRecording {
                        startRecordingSection
                    } else {
                        recordingControlsSection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(recordingService.currentMeeting?.title ?? "New Meeting")
                        .font(.headline)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if recordingService.isRecording {
                        Button("End") {
                            showEndMeetingAlert = true
                        }
                        .foregroundColor(.red)
                    } else if recordingService.currentMeeting != nil {
                        Button("New") {
                            showNewMeetingAlert = true
                        }
                    }
                }
            }
        }
        .alert("End Meeting?", isPresented: $showEndMeetingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Meeting", role: .destructive) {
                endMeeting()
            }
        } message: {
            Text("This will stop recording and save your meeting notes.")
        }
        .alert("Start New Meeting?", isPresented: $showNewMeetingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("New Meeting", role: .destructive) {
                startNewMeeting()
            }
        } message: {
            Text("This will save the current meeting and start a new one.")
        }
        .sheet(isPresented: $showTemplates) {
            TemplatePickerSheet(
                selectedTemplate: $selectedTemplate,
                onSelect: { template in
                    applyTemplate(template)
                    showTemplates = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeInOut(duration: 0.25)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        .onAppear {
            initializeMeeting()
        }
        .onChange(of: meetingTitle) { newValue in
            recordingService.updateTitle(newValue)
        }
    }
    
    private var startRecordingSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                TextField("Meeting Title", text: $meetingTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    Button(action: { showTemplates = true }) {
                        Label("Template", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: startMeeting) {
                        Label("Start Recording", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.05))
        }
    }
    
    private var recordingControlsSection: some View {
        Button(action: { showTemplates = true }) {
            Image(systemName: "doc.text")
                .font(.title2)
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
        }
        .padding()
        .background(Color.white)
        .shadow(radius: 2, y: -2)
    }
    
    private func startMeeting() {
        print("🚀 [MeetingView] startMeeting called")
        print("📝 [MeetingView] Using existing meeting")
        
        recordingService.startRecordingSession()
        isNotesFocused = true
        
        print("✅ [MeetingView] Recording started")
    }
    
    private func endMeeting() {
        print("🛑 [MeetingView] endMeeting called")
        print("📝 [MeetingView] Current notes length: \(userNotes.count) characters")
        
        recordingService.stopRecordingSession()
        isNotesFocused = false
        
        // Keep the meeting loaded for display
        loadCurrentMeeting()
        
        print("✅ [MeetingView] Recording stopped")
    }
    
    private func startNewMeeting() {
        print("🆕 [MeetingView] Starting new meeting")
        
        // Save current meeting if needed
        recordingService.saveMeeting()
        
        // Create new meeting (this will clear the transcript)
        recordingService.createNewMeeting()
        
        // Clear UI state
        userNotes = ""
        meetingTitle = ""
        selectedTemplate = nil
        
        // Don't reload from meeting since it's a new empty meeting
        // The UI will already show empty fields
        
        print("✅ [MeetingView] New meeting created")
    }
    
    private func initializeMeeting() {
        print("🏁 [MeetingView] Initializing meeting on appear")
        
        // Check if there's already a current meeting
        if recordingService.currentMeeting == nil {
            recordingService.createNewMeeting()
        }
        
        loadCurrentMeeting()
    }
    
    private func loadCurrentMeeting() {
        if let meeting = recordingService.currentMeeting {
            userNotes = meeting.rawNotes ?? ""
            meetingTitle = meeting.title ?? ""
            selectedTemplate = meeting.templateUsed
            
            // Load transcript if available and recording is not active
            if !recordingService.isRecording && !recordingService.currentTranscript.isEmpty {
                // Transcript is already in recordingService.currentTranscript
            } else if let savedTranscript = meeting.transcript, !savedTranscript.isEmpty {
                // Load saved transcript from meeting if service doesn't have it
                recordingService.currentTranscript = savedTranscript
            }
            
            print("📋 [MeetingView] Loaded meeting: \(meeting.title ?? "Untitled")")
            print("📝 [MeetingView] Transcript loaded: \(recordingService.currentTranscript.count) characters")
        }
    }
    
    private func applyTemplate(_ template: String) {
        switch template {
        case "1-on-1":
            userNotes = """
            ## Agenda
            - 
            
            ## Discussion Points
            - 
            
            ## Action Items
            - 
            
            ## Next Meeting
            - Date: 
            - Topics: 
            """
            
        case "Stand-up":
            userNotes = """
            ## Yesterday
            - 
            
            ## Today
            - 
            
            ## Blockers
            - 
            """
            
        case "Client Meeting":
            userNotes = """
            ## Attendees
            - 
            
            ## Agenda
            - 
            
            ## Notes
            
            
            ## Decisions
            - 
            
            ## Follow-up
            - 
            """
            
        case "Brainstorm":
            userNotes = """
            ## Topic
            
            
            ## Ideas
            - 
            
            ## Pros/Cons
            ### Pros
            - 
            
            ### Cons
            - 
            
            ## Next Steps
            - 
            """
            
        default:
            break
        }
        
        selectedTemplate = template
        recordingService.updateTemplate(template)
    }
}

struct TemplatePickerSheet: View {
    @Binding var selectedTemplate: String?
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    let templates = [
        ("1-on-1", "One-on-One", "Regular check-in meeting"),
        ("Stand-up", "Stand-up", "Daily team sync"),
        ("Client Meeting", "Client Meeting", "External meeting notes"),
        ("Brainstorm", "Brainstorm", "Creative session")
    ]
    
    var body: some View {
        NavigationView {
            List(templates, id: \.0) { template in
                Button(action: { onSelect(template.0) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.1)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(template.2)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}