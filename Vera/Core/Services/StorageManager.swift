import Foundation
import CoreData

class StorageManager {
    static let shared = StorageManager()
    
    private init() {}
    
    /// Clean up any leftover audio files (we no longer save audio)
    func cleanupOrphanedAudioFiles(context: NSManagedObjectContext) {
        print("🧹 [StorageManager] Cleaning up any leftover audio files")
        
        // Get documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // List all files in documents directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: documentsURL, 
                                                                       includingPropertiesForKeys: [.fileSizeKey]) else { return }
        
        var deletedCount = 0
        var totalSize: Int64 = 0
        
        for fileURL in files {
            let filename = fileURL.lastPathComponent
            
            // Delete ALL audio files (m4a or mp3) since we no longer save them
            if filename.hasSuffix(".m4a") || filename.hasSuffix(".mp3") {
                do {
                    let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let size = Int64(attributes.fileSize ?? 0)
                    
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                    totalSize += size
                    
                    print("🗑️ [StorageManager] Deleted leftover audio file: \(filename) (\(formatBytes(size)))")
                } catch {
                    print("❌ [StorageManager] Failed to delete \(filename): \(error)")
                }
            }
        }
        
        if deletedCount > 0 {
            print("✅ [StorageManager] Cleanup complete: Deleted \(deletedCount) audio files, freed \(formatBytes(totalSize))")
        } else {
            print("✅ [StorageManager] No leftover audio files found")
        }
    }
    
    /// Get total storage used by the app (no longer tracks audio files)
    func getStorageInfo() -> (totalSize: Int64, meetings: Int) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        var totalSize: Int64 = 0
        
        if let files = try? FileManager.default.contentsOfDirectory(at: documentsURL, 
                                                                    includingPropertiesForKeys: [.fileSizeKey]) {
            for fileURL in files {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                    totalSize += Int64(attributes.fileSize ?? 0)
                }
            }
        }
        
        let context = PersistenceController.shared.container.viewContext
        let meetingCount = (try? context.count(for: Meeting.fetchRequest())) ?? 0
        
        return (totalSize, meetingCount)
    }
    
    /// Delete old meetings
    func deleteOldMeetings(olderThan days: Int, context: NSManagedObjectContext) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        let request = Meeting.fetchRequest()
        request.predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)
        
        guard let oldMeetings = try? context.fetch(request) else { return }
        
        print("🗓️ [StorageManager] Found \(oldMeetings.count) meetings older than \(days) days")
        
        for meeting in oldMeetings {
            // No audio files to delete since we only save transcripts
            
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