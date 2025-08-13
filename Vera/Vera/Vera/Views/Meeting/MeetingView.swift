import SwiftUI
import CoreData

struct MeetingView: View {
    @StateObject private var recordingService = MeetingRecordingService()
    @State private var userNotes: String = ""
    @State private var showTemplates = false
    @State private var selectedTemplate: String?
    @State private var meetingTitle: String = ""
    @State private var showEndMeetingAlert = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isNotesFocused: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if recordingService.isRecording {
                        RecordingIndicatorView(
                            duration: recordingService.recordingDuration,
                            isPaused: recordingService.isPaused
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    NoteEditorView(
                        text: $userNotes,
                        isRecording: recordingService.isRecording,
                        onTextChange: { text in
                            if recordingService.isRecording {
                                recordingService.updateNotes(text)
                            }
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
                    if recordingService.isRecording {
                        Text(recordingService.currentMeeting?.title ?? "Meeting")
                            .font(.headline)
                    } else {
                        Text("New Meeting")
                            .font(.headline)
                    }
                }
                
                if recordingService.isRecording {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("End") {
                            showEndMeetingAlert = true
                        }
                        .foregroundColor(.red)
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
    }
    
    private var startRecordingSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                TextField("Meeting Title (optional)", text: $meetingTitle)
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
        HStack(spacing: 20) {
            Button(action: togglePause) {
                Image(systemName: recordingService.isPaused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Button(action: { showTemplates = true }) {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color.white)
        .shadow(radius: 2, y: -2)
    }
    
    private func startMeeting() {
        let title = meetingTitle.isEmpty ? nil : meetingTitle
        _ = recordingService.startMeeting(title: title, template: selectedTemplate)
        isNotesFocused = true
        
        if let template = selectedTemplate {
            applyTemplate(template)
        }
    }
    
    private func endMeeting() {
        recordingService.stopMeeting()
        userNotes = ""
        meetingTitle = ""
        selectedTemplate = nil
        isNotesFocused = false
    }
    
    private func togglePause() {
        if recordingService.isPaused {
            recordingService.resumeRecording()
        } else {
            recordingService.pauseRecording()
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