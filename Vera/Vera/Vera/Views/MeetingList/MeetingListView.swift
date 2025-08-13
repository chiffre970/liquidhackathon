import SwiftUI
import CoreData

struct MeetingListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Meeting.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Meeting.date, ascending: false)]
    ) private var meetings: FetchedResults<Meeting>
    
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var meetingToDelete: Meeting?
    
    var filteredMeetings: [Meeting] {
        if searchText.isEmpty {
            return Array(meetings)
        } else {
            return meetings.filter { meeting in
                let searchLower = searchText.lowercased()
                return meeting.title.lowercased().contains(searchLower) ||
                       (meeting.rawNotes?.lowercased().contains(searchLower) ?? false) ||
                       (meeting.transcript?.lowercased().contains(searchLower) ?? false) ||
                       (meeting.enhancedNotes?.lowercased().contains(searchLower) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
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
        .alert("Delete Meeting?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let meeting = meetingToDelete {
                    deleteMeeting(meeting)
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
            ForEach(filteredMeetings) { meeting in
                NavigationLink(destination: MeetingDetailPlaceholder(meeting: meeting)) {
                    MeetingRowView(meeting: meeting)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteFromList)
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await refreshMeetings()
        }
    }
    
    private func deleteFromList(at offsets: IndexSet) {
        for index in offsets {
            let meeting = filteredMeetings[index]
            meetingToDelete = meeting
            showingDeleteAlert = true
        }
    }
    
    private func deleteMeeting(_ meeting: Meeting) {
        withAnimation {
            if let audioURLString = meeting.audioFileURL,
               let audioURL = URL(string: audioURLString) {
                try? FileManager.default.removeItem(at: audioURL)
            }
            
            viewContext.delete(meeting)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to delete meeting: \(error)")
            }
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
                
                if !meeting.actionItemsArray.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Action Items")
                            .font(.headline)
                        ForEach(meeting.actionItemsArray, id: \.id) { item in
                            HStack {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                                Text(item.task)
                                Spacer()
                            }
                        }
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