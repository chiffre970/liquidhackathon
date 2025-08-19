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
                    // Custom Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondaryText)
                            .font(.system(size: 18, weight: .medium))
                        
                        TextField("", text: $searchText, prompt: Text("Search meetings").foregroundColor(.secondaryText))
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.primaryText)
                            .accentColor(.secondaryText)
                            .font(.system(size: 16, weight: .regular))
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                    .frame(height: 46) // Reduced height
                    .padding(.horizontal, 20) // Slightly less padding
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    // List content (no divider under search)
                    List {
                        ForEach(filteredMeetings) { meeting in
                            NavigationLink(destination: SingleNoteView(meeting: meeting)) {
                                NoteRowView(meeting: meeting)
                            }
                            .id(meeting.objectID)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .overlay(
                                // Custom separator matching search bar width
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 0),
                                alignment: .bottom
                            )
                        }
                        .onDelete(perform: deleteMeetings)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .tint(.secondaryText)
                }
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
            .navigationBarTitleDisplayMode(.large)
        }
        .tint(.secondaryText)
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
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                if !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(dateString)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 8)  // Add internal padding to move content inward
        .frame(height: 85)
        .frame(maxWidth: .infinity)
        }
    }
}
