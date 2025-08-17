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
                        .id(meeting.objectID)  // Use Core Data's objectID for stable identity
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
        print("🗑️ [DELETE] Starting deletion with offsets: \(offsets)")
        
        withAnimation {
            for index in offsets {
                print("🗑️ [DELETE] Processing index: \(index)")
                
                // Safety check for array bounds
                guard index < filteredMeetings.count else {
                    print("❌ [DELETE] Index \(index) out of bounds (count: \(filteredMeetings.count))")
                    continue
                }
                
                let meeting = filteredMeetings[index]
                print("🗑️ [DELETE] Deleting meeting: \(meeting.title.isEmpty ? "Untitled" : meeting.title) with ID: \(meeting.id.uuidString)")
                
                // Check if meeting is valid before deletion
                if meeting.isFault {
                    print("⚠️ [DELETE] Meeting is a fault, refreshing...")
                    viewContext.refresh(meeting, mergeChanges: false)
                }
                
                viewContext.delete(meeting)
                print("✅ [DELETE] Meeting marked for deletion")
            }
            
            do {
                print("💾 [DELETE] Saving context...")
                try viewContext.save()
                print("✅ [DELETE] Context saved successfully")
            } catch let error as NSError {
                print("❌ [DELETE] Failed to save after deletion:")
                print("   Error: \(error.localizedDescription)")
                print("   User Info: \(error.userInfo)")
                
                // Try to rollback if save fails
                viewContext.rollback()
                print("🔄 [DELETE] Context rolled back")
            }
        }
        
        print("🗑️ [DELETE] Deletion process completed")
    }
}

struct NoteRowView: View {
    @ObservedObject var meeting: Meeting
    
    private var preview: String {
        // Check if meeting is deleted or faulted
        if meeting.isDeleted || meeting.isFault {
            return "No content"
        }
        if let notes = meeting.rawNotes, !notes.isEmpty {
            return notes
        } else if let transcript = meeting.transcript, !transcript.isEmpty {
            return transcript
        } else {
            return "No content"
        }
    }
    
    private var dateString: String {
        // Check if meeting is deleted before accessing properties
        guard !meeting.isDeleted && !meeting.isFault else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: meeting.date)
    }
    
    var body: some View {
        // Don't render if meeting is deleted
        if meeting.isDeleted {
            EmptyView()
        } else {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title.isEmpty ? "Untitled" : meeting.title)
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
}
