import SwiftUI
import CoreData

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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                headerSection
                
                // Meeting Info
                meetingInfoSection
                
                // Tab Selection
                Picker("View", selection: $selectedTab) {
                    Text("Transcript").tag(0)
                    Text("Notes").tag(1)
                    Text("Summary").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        transcriptSection
                    case 1:
                        notesSection
                    case 2:
                        summarySection
                    default:
                        EmptyView()
                    }
                }
                
                // Action Items
                if !meeting.actionItemsArray.isEmpty {
                    actionItemsSection
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingExportSheet = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { isEditingTitle = true }) {
                        Label("Edit Title", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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
            ExportView(meeting: meeting)
        }
        .sheet(isPresented: $isEditingTitle) {
            EditTitleView(meeting: meeting, title: $editedTitle) {
                saveTitle()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meeting.title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                Label {
                    Text(meeting.date, style: .date)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                }
                
                Label {
                    Text(meeting.formattedDuration)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
                
                if let template = meeting.templateUsed {
                    Label {
                        Text(template)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var meetingInfoSection: some View {
        HStack(spacing: 20) {
            InfoCard(
                title: "Words",
                value: "\(wordCount)",
                icon: "text.word.spacing",
                color: .blue
            )
            
            InfoCard(
                title: "Actions",
                value: "\(meeting.actionItemsArray.count)",
                icon: "checklist",
                color: .orange
            )
            
            InfoCard(
                title: "Decisions",
                value: "\(meeting.keyDecisionsArray.count)",
                icon: "lightbulb",
                color: .green
            )
        }
        .padding(.horizontal)
    }
    
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Transcript", systemImage: "mic.fill")
                    .font(.headline)
                Spacer()
                if let transcript = meeting.transcript, !transcript.isEmpty {
                    Text("\(transcript.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            if let transcript = meeting.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.body)
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                Text("No transcript available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
    }
    
    private var notesSection: some View {
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
            .padding(.horizontal)
            
            if let notes = meeting.rawNotes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                Text("No notes added")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $isEditingNotes) {
            EditNotesView(meeting: meeting, notes: $editedNotes) {
                saveNotes()
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Enhanced Summary", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            if let enhancedNotes = meeting.enhancedNotes, !enhancedNotes.isEmpty {
                Text(enhancedNotes)
                    .font(.body)
                    .padding()
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("AI summary will appear here")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                    Text("Coming in Phase 4")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Action Items", systemImage: "checklist")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(meeting.actionItemsArray, id: \.id) { item in
                ActionItemRow(item: item) { updatedItem in
                    updateActionItem(updatedItem)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var wordCount: Int {
        let transcript = meeting.transcript ?? ""
        let notes = meeting.rawNotes ?? ""
        let combined = transcript + " " + notes
        return combined.split(separator: " ").count
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
    
    private func updateActionItem(_ item: ActionItem) {
        var items = meeting.actionItemsArray
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            meeting.actionItemsArray = items
            do {
                try viewContext.save()
            } catch {
                print("Failed to update action item: \(error)")
            }
        }
    }
    
    private func deleteMeeting() {
        viewContext.delete(meeting)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to delete meeting: \(error)")
        }
    }
}

struct InfoCard: View {
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

struct ActionItemRow: View {
    let item: ActionItem
    let onUpdate: (ActionItem) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                var updatedItem = item
                updatedItem = ActionItem(
                    id: item.id,
                    task: item.task,
                    owner: item.owner,
                    deadline: item.deadline,
                    isCompleted: !item.isCompleted
                )
                onUpdate(updatedItem)
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.task)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                
                if let owner = item.owner {
                    Text("Assigned to: \(owner)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let deadline = item.deadline {
                    Text("Due: \(deadline, style: .date)")
                        .font(.caption)
                        .foregroundColor(isOverdue(deadline) ? .red : .secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !item.isCompleted
    }
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
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat = "markdown"
    
    var body: some View {
        NavigationView {
            List {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        Text("Markdown").tag("markdown")
                        Text("Plain Text").tag("text")
                        Text("PDF").tag("pdf")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Button(action: exportMeeting) {
                        Label("Export Meeting", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Export Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportMeeting() {
        // Export functionality will be implemented in Phase 5
        print("Exporting meeting in \(selectedFormat) format")
        dismiss()
    }
}