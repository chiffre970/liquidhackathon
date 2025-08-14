import SwiftUI
import CoreData
import AVFoundation

struct MeetingDetailView: View {
    @ObservedObject var meeting: Meeting
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isEditingNotes = false
    @State private var editedNotes = ""
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var selectedTab = 0
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            if let status = meeting.processingStatus {
                processingStatusBanner(status: status)
            }
            
            TabView(selection: $selectedTab) {
                overviewTab
                    .tag(0)
                    .tabItem {
                        Label("Overview", systemImage: "chart.bar.doc.horizontal")
                    }
                
                actionItemsTab
                    .tag(1)
                    .tabItem {
                        Label("Actions", systemImage: "checklist")
                    }
                    .badge(incompletedActionCount)
                
                decisionsTab
                    .tag(2)
                    .tabItem {
                        Label("Decisions", systemImage: "lightbulb")
                    }
                
                questionsTab
                    .tag(3)
                    .tabItem {
                        Label("Questions", systemImage: "questionmark.circle")
                    }
                    .badge(unansweredQuestionsCount)
                
                transcriptTab
                    .tag(4)
                    .tabItem {
                        Label("Transcript", systemImage: "mic")
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarMenu
            }
        }
        .alert("Delete Meeting?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMeeting()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView(meeting: meeting) { url in
                exportedFileURL = url
                showingShareSheet = true
            }
        }
        .sheet(isPresented: $isEditingTitle) {
            EditTitleView(meeting: meeting, title: $editedTitle) {
                saveTitle()
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            audioPlayer?.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MeetingEnhancementCompleted"))) { notification in
            if let meetingId = notification.object as? UUID,
               meetingId == meeting.id {
                viewContext.refresh(meeting, mergeChanges: true)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(meeting.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    InfoChip(
                        icon: "calendar",
                        text: meeting.date.formatted(date: .abbreviated, time: .omitted)
                    )
                    
                    InfoChip(
                        icon: "clock",
                        text: meeting.formattedDuration
                    )
                    
                    if let template = meeting.templateUsed {
                        InfoChip(
                            icon: "doc.text",
                            text: template
                        )
                    }
                    
                    if meeting.audioFileURL != nil {
                        Button(action: toggleAudioPlayback) {
                            HStack(spacing: 4) {
                                Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                                Text(isPlayingAudio ? "Pause" : "Play")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        .padding(.top)
    }
    
    private func processingStatusBanner(status: String) -> some View {
        HStack {
            switch ProcessingStatus(rawValue: status) {
            case .processing:
                ProgressView()
                    .scaleEffect(0.8)
                Text("Enhancing with AI...")
                    .font(.caption)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("AI Enhancement Complete")
                    .font(.caption)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Enhancement Failed")
                    .font(.caption)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
    }
    
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let insights = meeting.meetingInsights {
                    insightsSection(insights: insights)
                }
                
                if let enhancedNotes = meeting.enhancedNotes, !enhancedNotes.isEmpty {
                    enhancedNotesSection(notes: enhancedNotes)
                } else {
                    rawNotesSection
                }
                
                statisticsSection
            }
            .padding()
        }
    }
    
    private func insightsSection(insights: MeetingInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Insights", systemImage: "sparkles")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Executive Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(insights.executiveSummary)
                    .font(.body)
                
                if !insights.keyPoints.isEmpty {
                    Text("Key Points")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    ForEach(insights.keyPoints, id: \.self) { point in
                        HStack(alignment: .top) {
                            Text("•")
                            Text(point)
                        }
                        .font(.body)
                    }
                }
                
                if let critical = insights.criticalInfo {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(critical)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.top, 8)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func enhancedNotesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Enhanced Summary", systemImage: "wand.and.stars")
                .font(.headline)
            
            Text(notes)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
        }
    }
    
    private var rawNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Notes", systemImage: "note.text")
                    .font(.headline)
                Spacer()
                Button(action: { isEditingNotes = true }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.accentColor)
                }
            }
            
            Text(meeting.rawNotes ?? "No notes added")
                .font(.body)
                .foregroundColor((meeting.rawNotes ?? "").isEmpty ? .secondary : .primary)
                .italic((meeting.rawNotes ?? "").isEmpty)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
        }
        .sheet(isPresented: $isEditingNotes) {
            EditNotesView(meeting: meeting, notes: $editedNotes) {
                saveNotes()
            }
        }
    }
    
    private var statisticsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Words",
                value: "\(wordCount)",
                icon: "text.word.spacing",
                color: .blue
            )
            
            StatCard(
                title: "Actions",
                value: "\(meeting.actionItemsArray.count)",
                icon: "checklist",
                color: .orange
            )
            
            StatCard(
                title: "Decisions",
                value: "\(meeting.keyDecisionsArray.count)",
                icon: "lightbulb",
                color: .green
            )
            
            StatCard(
                title: "Questions",
                value: "\(meeting.questionsArray.count)",
                icon: "questionmark.circle",
                color: .purple
            )
        }
    }
    
    private var actionItemsTab: some View {
        ActionItemsView(meeting: meeting)
    }
    
    private var decisionsTab: some View {
        DecisionsTimelineView(meeting: meeting)
    }
    
    private var questionsTab: some View {
        QuestionsView(meeting: meeting)
    }
    
    private var transcriptTab: some View {
        TranscriptView(meeting: meeting)
    }
    
    private var toolbarMenu: some View {
        Menu {
            Button(action: { showingExportSheet = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            
            Button(action: { isEditingTitle = true }) {
                Label("Edit Title", systemImage: "pencil")
            }
            
            Button(action: reprocessWithAI) {
                Label("Reprocess with AI", systemImage: "arrow.clockwise")
            }
            .disabled(meeting.transcript?.isEmpty ?? true)
            
            Divider()
            
            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    private var incompletedActionCount: Int {
        meeting.actionItemsArray.filter { !$0.isCompleted }.count
    }
    
    private var unansweredQuestionsCount: Int {
        meeting.questionsArray.filter { $0.needsFollowUp }.count
    }
    
    private var wordCount: Int {
        let transcript = meeting.transcript ?? ""
        let notes = meeting.rawNotes ?? ""
        let combined = transcript + " " + notes
        return combined.split(separator: " ").count
    }
    
    private func setupAudioPlayer() {
        guard let urlString = meeting.audioFileURL,
              let url = URL(string: urlString) else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to setup audio player: \(error)")
        }
    }
    
    private func toggleAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        isPlayingAudio.toggle()
    }
    
    private func reprocessWithAI() {
        meeting.processingStatus = ProcessingStatus.pending.rawValue
        
        Task {
            let enhancementService = MeetingEnhancementService.shared
            try? await enhancementService.enhanceMeeting(meeting, context: viewContext)
        }
    }
    
    private func saveTitle() {
        meeting.title = editedTitle.isEmpty ? meeting.title : editedTitle
        do {
            try viewContext.save()
        } catch {
            print("Failed to save title: \(error)")
        }
        isEditingTitle = false
    }
    
    private func saveNotes() {
        meeting.rawNotes = editedNotes
        do {
            try viewContext.save()
        } catch {
            print("Failed to save notes: \(error)")
        }
        isEditingNotes = false
    }
    
    private func deleteMeeting() {
        if let urlString = meeting.audioFileURL,
           let url = URL(string: urlString) {
            try? FileManager.default.removeItem(at: url)
        }
        
        viewContext.delete(meeting)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to delete meeting: \(error)")
        }
    }
}

struct InfoChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct EditTitleView: View {
    @ObservedObject var meeting: Meeting
    @Binding var title: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Meeting Title", text: $title)
            }
            .navigationTitle("Edit Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
        .onAppear {
            title = meeting.title
        }
    }
}

struct EditNotesView: View {
    @ObservedObject var meeting: Meeting
    @Binding var notes: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            TextEditor(text: $notes)
                .padding()
                .navigationTitle("Edit Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            onSave()
                        }
                    }
                }
        }
        .onAppear {
            notes = meeting.rawNotes ?? ""
        }
    }
}

struct ExportView: View {
    let meeting: Meeting
    let onExport: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat = "markdown"
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        Text("Markdown").tag("markdown")
                        Text("Plain Text").tag("text")
                        Text("PDF").tag("pdf")
                        Text("JSON").tag("json")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Button(action: exportMeeting) {
                        if isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Export Meeting", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("Export Meeting")
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
    
    private func exportMeeting() {
        isExporting = true
        
        Task {
            let exportService = ExportService()
            if let url = await exportService.export(meeting, format: selectedFormat) {
                await MainActor.run {
                    onExport(url)
                    dismiss()
                }
            }
            
            await MainActor.run {
                isExporting = false
            }
        }
    }
}