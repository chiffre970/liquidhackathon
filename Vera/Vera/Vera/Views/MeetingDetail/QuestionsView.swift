import SwiftUI

struct QuestionsView: View {
    @ObservedObject var meeting: Meeting
    
    var body: some View {
        ScrollView {
            if meeting.questionsArray.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No questions recorded")
                        .font(.headline)
                    
                    Text("Open questions will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(meeting.questionsArray, id: \.id) { question in
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(question.question)
                                    .font(.body)
                                
                                if let context = question.context {
                                    Text(context)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    if let assignedTo = question.assignedTo {
                                        Label(assignedTo, systemImage: "person")
                                            .font(.caption2)
                                    }
                                    
                                    Label(question.urgency.rawValue.capitalized, systemImage: "flag")
                                        .font(.caption2)
                                        .foregroundColor(urgencyColor(question.urgency))
                                }
                            }
                            
                            Spacer()
                            
                            if question.needsFollowUp {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Questions")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func urgencyColor(_ urgency: Question.Urgency) -> Color {
        switch urgency {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}