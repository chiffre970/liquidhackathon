import SwiftUI

struct TranscriptView: View {
    @ObservedObject var meeting: Meeting
    @State private var searchText = ""
    @State private var fontSize: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if meeting.transcript?.isEmpty == false {
                ScrollView {
                    highlightedTranscript
                }
            } else {
                emptyState
            }
            
            fontSizeControl
        }
        .navigationTitle("Transcript")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search transcript...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
    
    private func buildHighlightedText(from transcript: String) -> Text {
        if searchText.isEmpty {
            return Text(transcript)
        }
        
        let searchLower = searchText.lowercased()
        let transcriptLower = transcript.lowercased()
        
        var result = Text("")
        var currentIndex = transcript.startIndex
        
        while currentIndex < transcript.endIndex {
            if let range = transcriptLower.range(of: searchLower, options: [], range: currentIndex..<transcriptLower.endIndex) {
                // Add text before the match
                let beforeMatch = String(transcript[currentIndex..<range.lowerBound])
                result = result + Text(beforeMatch)
                
                // Add the highlighted match
                let match = String(transcript[range.lowerBound..<range.upperBound])
                result = result + Text(match)
                    .foregroundColor(.orange)
                    .bold()
                
                currentIndex = range.upperBound
            } else {
                // No more matches, add remaining text
                let remaining = String(transcript[currentIndex..<transcript.endIndex])
                result = result + Text(remaining)
                break
            }
        }
        
        return result
    }
    
    @ViewBuilder
    private var highlightedTranscript: some View {
        if let transcript = meeting.transcript {
            buildHighlightedText(from: transcript)
                .font(.system(size: fontSize))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No transcript available")
                .font(.headline)
            
            Text("The transcript will appear here after recording")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var fontSizeControl: some View {
        HStack {
            Text("Text Size")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(value: $fontSize, in: 12...24, step: 1)
                .frame(width: 150)
            
            Text("\(Int(fontSize))pt")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 35)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
}