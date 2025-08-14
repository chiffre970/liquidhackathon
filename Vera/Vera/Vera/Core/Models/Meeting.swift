import Foundation
import CoreData

enum ProcessingStatus: String {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
}

@objc(Meeting)
public class Meeting: NSManagedObject {
    
}

extension Meeting {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Meeting> {
        return NSFetchRequest<Meeting>(entityName: "Meeting")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var date: Date
    @NSManaged public var duration: TimeInterval
    @NSManaged public var rawNotes: String?
    @NSManaged public var transcript: String?
    @NSManaged public var enhancedNotes: String?
    @NSManaged public var templateUsed: String?
    @NSManaged public var insights: Data?
    @NSManaged public var processingStatus: String?
    @NSManaged public var lastProcessedDate: Date?
}

extension Meeting: Identifiable {
    
}


struct MeetingInsights: Codable {
    let executiveSummary: String
    let keyPoints: [String]
    let criticalInfo: String?
    let unresolvedTopics: [String]
    let risks: [String]
    let followUpItems: [String]
    
    init(executiveSummary: String = "", keyPoints: [String] = [], criticalInfo: String? = nil, unresolvedTopics: [String] = [], risks: [String] = [], followUpItems: [String] = []) {
        self.executiveSummary = executiveSummary
        self.keyPoints = keyPoints
        self.criticalInfo = criticalInfo
        self.unresolvedTopics = unresolvedTopics
        self.risks = risks
        self.followUpItems = followUpItems
    }
}

extension Meeting {
    
    var meetingInsights: MeetingInsights? {
        get {
            guard let data = insights else { return nil }
            return try? JSONDecoder().decode(MeetingInsights.self, from: data)
        }
        set {
            insights = try? JSONEncoder().encode(newValue)
        }
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
}