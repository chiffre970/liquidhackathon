import SwiftUI
import CoreData

struct MeetingListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Meeting.date, ascending: false)],
        animation: .default
    ) private var meetings: FetchedResults<Meeting>
    
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var meetingToDelete: Meeting?
    
    init() {
        print("🔵 [MeetingListView] Initializing")
    }
    
    var filteredMeetings: [Meeting] {
        print("🔍 [MeetingListView] Filtering meetings - total: \(meetings.count), search: '\(searchText)'")
        
        if searchText.isEmpty {
            return Array(meetings)
        } else {
            return meetings.filter { meeting in
                let searchLower = searchText.lowercased()
                
                // Safe access to title with nil check
                let titleMatch = (meeting.title ?? "").lowercased().contains(searchLower)
                let notesMatch = (meeting.rawNotes?.lowercased().contains(searchLower) ?? false)
                let transcriptMatch = (meeting.transcript?.lowercased().contains(searchLower) ?? false)
                let enhancedNotesMatch = (meeting.enhancedNotes?.lowercased().contains(searchLower) ?? false)
                
                return titleMatch || notesMatch || transcriptMatch || enhancedNotesMatch
            }
        }
    }
    
    var body: some View {
        print("🔵 [MeetingListView] Rendering body - meetings count: \(meetings.count)")
        
        return NavigationView {
            VStack(spacing: 0) {
                if !meetings.isEmpty {
                    MeetingSearchBar(searchText: $searchText)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                if meetings.isEmpty {
                    emptyStateView
                } else if filteredMeetings.isEmpty {
                    noResultsView
                } else {
                    meetingsList
                }
            }
            .navigationTitle("Meetings")
            .background(Color.gray.opacity(0.05))
        }
        .onAppear {
            print("✅ [MeetingListView] View appeared")
            print("📊 [MeetingListView] Meetings count: \(meetings.count)")
            for (index, meeting) in meetings.enumerated() {
                print("  Meeting \(index): ID=\(meeting.id.uuidString), Title=\(meeting.title)")
            }
        }
        .alert("Delete Meeting?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let meeting = meetingToDelete {
                    print("🗑️ [MeetingListView] Delete button pressed for meeting: \(meeting.id.uuidString)")
                    deleteMeeting(meeting)
                    meetingToDelete = nil
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Meetings Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start recording your first meeting\nfrom the Record tab")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try a different search term")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    private var meetingsList: some View {
        List {
            ForEach(filteredMeetings, id: \.id) { meeting in
                NavigationLink(destination: MeetingDetailView(meeting: meeting)) {
                    MeetingRowView(meeting: meeting)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        print("🗑️ [MeetingListView] Swipe action delete for meeting: \(meeting.id.uuidString)")
                        deleteMeeting(meeting)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await refreshMeetings()
        }
    }
    
    private func deleteFromList(at offsets: IndexSet) {
        print("🗑️ [MeetingListView] Swipe delete triggered")
        
        // For swipe-to-delete, delete immediately without alert
        for index in offsets {
            if index < filteredMeetings.count {
                let meeting = filteredMeetings[index]
                print("🗑️ [MeetingListView] Deleting meeting at index \(index): \(meeting.id.uuidString)")
                deleteMeeting(meeting)
            }
        }
    }
    
    private func deleteMeeting(_ meeting: Meeting) {
        print("🗑️ [MeetingListView] Deleting meeting: \(meeting.id.uuidString)")
        
        // No audio files to delete since we only save transcripts
        
        // Delete from Core Data synchronously on main thread
        viewContext.delete(meeting)
        
        do {
            try viewContext.save()
            print("✅ [MeetingListView] Meeting deleted from Core Data")
        } catch {
            print("❌ [MeetingListView] Failed to delete meeting from Core Data: \(error)")
        }
    }
    
    private func refreshMeetings() async {
        await MainActor.run {
            do {
                try viewContext.save()
            } catch {
                print("Failed to refresh: \(error)")
            }
        }
    }
}

struct MeetingDetailPlaceholder: View {
    let meeting: Meeting
    
    init(meeting: Meeting) {
        self.meeting = meeting
        print("🔵 [MeetingDetailPlaceholder] Initializing with meeting: ID=\(meeting.id.uuidString)")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(meeting.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(meeting.date, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    
                    Label {
                        Text(meeting.formattedDuration)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    
                    if let template = meeting.templateUsed {
                        Label {
                            Text(template)
                        } icon: {
                            Image(systemName: "doc.text")
                        }
                    }
                }
                .padding(.horizontal)
                
                if let notes = meeting.rawNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}