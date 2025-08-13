import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting
    
    private var firstTwoLines: String {
        let notes = meeting.rawNotes ?? meeting.transcript ?? ""
        let lines = notes.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .prefix(2)
        return lines.joined(separator: " ")
    }
    
    private var actionItemCount: Int {
        meeting.actionItemsArray.filter { !$0.isCompleted }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label {
                            Text(meeting.date, style: .date)
                                .font(.caption)
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        Label {
                            Text(meeting.formattedDuration)
                                .font(.caption)
                        } icon: {
                            Image(systemName: "clock")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if actionItemCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                            .font(.caption)
                        Text("\(actionItemCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                }
            }
            
            if !firstTwoLines.isEmpty {
                Text(firstTwoLines)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            if let template = meeting.templateUsed {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text(template)
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}