import SwiftUI

struct DecisionsTimelineView: View {
    @ObservedObject var meeting: Meeting
    
    var body: some View {
        ScrollView {
            if meeting.keyDecisionsArray.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No decisions recorded")
                        .font(.headline)
                    
                    Text("Key decisions will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(meeting.keyDecisionsArray, id: \.id) { decision in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(decision.decision)
                                .font(.body)
                            
                            if let context = decision.context {
                                Text(context)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(decision.timestamp.formatted())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Decisions")
        .navigationBarTitleDisplayMode(.inline)
    }
}