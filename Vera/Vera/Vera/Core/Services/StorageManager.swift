import Foundation
import CoreData

class StorageManager {
    static let shared = StorageManager()
    
    private init() {}
    
    /// Clean up orphaned audio files that don't have corresponding meetings
    func cleanupOrphanedAudioFiles(context: NSManagedObjectContext) {
        print("🧹 [StorageManager] Starting cleanup of orphaned audio files")
        
        // Get all meetings and their audio file URLs
        let request = Meeting.fetchRequest()
        guard let meetings = try? context.fetch(request) else { return }
        
        let validAudioFiles = Set(meetings.compactMap { meeting -> String? in
            guard let url = meeting.audioURL else { return nil }
            return url.lastPathComponent
        })
        
        print("📊 [StorageManager] Found \(validAudioFiles.count) valid audio files from \(meetings.count) meetings")
        
        // Get documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // List all files in documents directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: documentsURL, 
                                                                       includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else { return }
        
        var deletedCount = 0
        var totalSize: Int64 = 0
        
        for fileURL in files {
            let filename = fileURL.lastPathComponent
            
            // Check if it's an audio file (m4a or mp3)
            if (filename.hasSuffix(".m4a") || filename.hasSuffix(".mp3")) && !validAudioFiles.contains(filename) {
                do {
                    let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let size = Int64(attributes.fileSize ?? 0)
                    
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                    totalSize += size
                    
                    print("🗑️ [StorageManager] Deleted orphaned file: \(filename) (\(formatBytes(size)))")
                } catch {
                    print("❌ [StorageManager] Failed to delete \(filename): \(error)")
                }
            }
        }
        
        if deletedCount > 0 {
            print("✅ [StorageManager] Cleanup complete: Deleted \(deletedCount) files, freed \(formatBytes(totalSize))")
        } else {
            print("✅ [StorageManager] No orphaned files found")
        }
    }
    
    /// Get total storage used by the app
    func getStorageInfo() -> (totalSize: Int64, audioFiles: Int, meetings: Int) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        var totalSize: Int64 = 0
        var audioFileCount = 0
        
        if let files = try? FileManager.default.contentsOfDirectory(at: documentsURL, 
                                                                    includingPropertiesForKeys: [.fileSizeKey]) {
            for fileURL in files {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                    totalSize += Int64(attributes.fileSize ?? 0)
                    
                    if fileURL.pathExtension == "m4a" || fileURL.pathExtension == "mp3" {
                        audioFileCount += 1
                    }
                }
            }
        }
        
        let context = PersistenceController.shared.container.viewContext
        let meetingCount = (try? context.count(for: Meeting.fetchRequest())) ?? 0
        
        return (totalSize, audioFileCount, meetingCount)
    }
    
    /// Delete old meetings and their audio files
    func deleteOldMeetings(olderThan days: Int, context: NSManagedObjectContext) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        let request = Meeting.fetchRequest()
        request.predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)
        
        guard let oldMeetings = try? context.fetch(request) else { return }
        
        print("🗓️ [StorageManager] Found \(oldMeetings.count) meetings older than \(days) days")
        
        for meeting in oldMeetings {
            // Delete audio file
            if let audioURL = meeting.audioURL {
                try? FileManager.default.removeItem(at: audioURL)
            }
            
            // Delete meeting
            context.delete(meeting)
        }
        
        try? context.save()
        print("✅ [StorageManager] Deleted \(oldMeetings.count) old meetings")
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}