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
                let title = meeting.title ?? ""
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
                    HStack {
                        Spacer()
                        Button(action: createNewNote) {
                            Image(systemName: "square.and.pencil")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Meetings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
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
    let meeting: Meeting
    
    private var preview: String {
        if let notes = meeting.rawNotes, !notes.isEmpty {
            return notes
        } else if let transcript = meeting.transcript, !transcript.isEmpty {
            return transcript
        } else {
            return "No content"
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: meeting.date ?? Date())
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(dateString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
