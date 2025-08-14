import Foundation
import UIKit

class ExportService {
    
    func export(_ meeting: Meeting, format: String) async -> URL? {
        let fileName = "\(meeting.title.replacingOccurrences(of: " ", with: "_")).\(format == "markdown" ? "md" : "txt")"
        // Use temporary directory for exports (they're meant to be shared immediately)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let content: String
        switch format {
        case "markdown":
            content = exportAsMarkdown(meeting)
        default:
            content = exportAsPlainText(meeting)
        }
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Failed to export: \(error)")
            return nil
        }
    }
    
    private func exportAsMarkdown(_ meeting: Meeting) -> String {
        var content = "# \(meeting.title)\n\n"
        content += "**Date:** \(meeting.date.formatted())\n"
        content += "**Duration:** \(meeting.formattedDuration)\n\n"
        
        if let summary = meeting.enhancedNotes, !summary.isEmpty {
            content += "## Summary\n\(summary)\n\n"
        }
        
        if let notes = meeting.rawNotes, !notes.isEmpty {
            content += "## Notes\n\(notes)\n\n"
        }
        
        if let transcript = meeting.transcript, !transcript.isEmpty {
            content += "## Transcript\n\(transcript)\n"
        }
        
        return content
    }
    
    private func exportAsPlainText(_ meeting: Meeting) -> String {
        var content = "\(meeting.title)\n"
        content += "=================\n\n"
        content += "Date: \(meeting.date.formatted())\n"
        content += "Duration: \(meeting.formattedDuration)\n\n"
        
        if let summary = meeting.enhancedNotes, !summary.isEmpty {
            content += "SUMMARY\n-------\n\(summary)\n\n"
        }
        
        if let notes = meeting.rawNotes, !notes.isEmpty {
            content += "NOTES\n-----\n\(notes)\n\n"
        }
        
        if let transcript = meeting.transcript, !transcript.isEmpty {
            content += "TRANSCRIPT\n----------\n\(transcript)\n"
        }
        
        return content
    }
}