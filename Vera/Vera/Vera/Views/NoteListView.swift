import SwiftUI
import CoreData

struct NoteListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Meeting.date, ascending: false)],
        animation: .default)
    private var meetings: FetchedResults<Meeting>
    
    @State private var searchText = ""
    @State private var selectedMeeting: Meeting?
    @State private var showingNote = false
    
    var filteredMeetings: [Meeting] {
        if searchText.isEmpty {
            return Array(meetings)
        } else {
            return meetings.filter { meeting in
                let title = meeting.title
                let notes = meeting.rawNotes ?? ""
                let transcript = meeting.transcript ?? ""
                return title.localizedCaseInsensitiveContains(searchText) ||
                       notes.localizedCaseInsensitiveContains(searchText) ||
                       transcript.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(filteredMeetings) { meeting in
                        NavigationLink(destination: SingleNoteView(meeting: meeting)) {
                            NoteRowView(meeting: meeting)
                        }
                        .id(meeting.objectID)
                        .listRowSeparatorTint(.gray.opacity(0.3))
                        .listRowSeparator(.visible, edges: .bottom)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .alignmentGuide(.listRowSeparatorTrailing) { d in d.width - 16 }
                    }
                    .onDelete(perform: deleteMeetings)
                }
                .listStyle(PlainListStyle())
                .searchable(text: $searchText, prompt: "Search meetings")
                .navigationDestination(isPresented: $showingNote) {
                    if let meeting = selectedMeeting {
                        SingleNoteView(meeting: meeting)
                    }
                }
                
                // New Note Button (floating)
                VStack {
                    Spacer()
                    FloatingActionButton(
                        title: "New Meeting",
                        icon: "plus.circle.fill",
                        action: createNewNote
                    )
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Meetings")
        }
    }
    
    private func createNewNote() {
        let newMeeting = Meeting(context: viewContext)
        newMeeting.id = UUID()
        newMeeting.date = Date()
        newMeeting.title = "New Meeting"
        newMeeting.rawNotes = ""
        
        do {
            try viewContext.save()
            selectedMeeting = newMeeting
            showingNote = true
        } catch {
            print("Failed to create new meeting: \(error)")
        }
    }
    
    private func deleteMeetings(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredMeetings[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to delete meetings: \(error)")
            }
        }
    }
}

struct NoteRowView: View {
    @ObservedObject var meeting: Meeting
    
    private var preview: String {
        if meeting.isDeleted || meeting.isFault {
            return ""
        }
        
        // Show subtitle/preview if available
        if let subtitle = meeting.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        
        // Show nothing while waiting for AI to generate preview
        return ""
    }
    
    private var dateString: String {
        guard !meeting.isDeleted && !meeting.isFault else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: meeting.date)
    }
    
    var body: some View {
        if meeting.isDeleted {
            EmptyView()
        } else {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title.isEmpty ? "Untitled" : meeting.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(dateString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 65)
        .frame(maxWidth: .infinity)
        }
    }
}
