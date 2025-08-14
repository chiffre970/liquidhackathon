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
    @NSManaged public var actionItems: Data?
    @NSManaged public var keyDecisions: Data?
    @NSManaged public var questions: Data?
    @NSManaged public var templateUsed: String?
    @NSManaged public var insights: Data?
    @NSManaged public var processingStatus: String?
    @NSManaged public var lastProcessedDate: Date?
}

extension Meeting: Identifiable {
    
}

struct ActionItem: Codable {
    let id: UUID
    let task: String
    let owner: String?
    let deadline: Date?
    var isCompleted: Bool
    let priority: Priority
    let context: String?
    
    enum Priority: String, Codable {
        case urgent = "urgent"
        case high = "high"
        case medium = "medium"
        case low = "low"
    }
    
    init(id: UUID = UUID(), task: String, owner: String? = nil, deadline: Date? = nil, isCompleted: Bool = false, priority: Priority = .medium, context: String? = nil) {
        self.id = id
        self.task = task
        self.owner = owner
        self.deadline = deadline
        self.isCompleted = isCompleted
        self.priority = priority
        self.context = context
    }
}

struct KeyDecision: Codable {
    let id: UUID
    let decision: String
    let context: String?
    let impact: String?
    let timestamp: Date
    
    init(id: UUID = UUID(), decision: String, context: String? = nil, impact: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.decision = decision
        self.context = context
        self.impact = impact
        self.timestamp = timestamp
    }
}

struct Question: Codable {
    let id: UUID
    let question: String
    let context: String?
    var needsFollowUp: Bool
    let assignedTo: String?
    let urgency: Urgency
    
    enum Urgency: String, Codable {
        case high = "high"
        case medium = "medium"
        case low = "low"
    }
    
    init(id: UUID = UUID(), question: String, context: String? = nil, needsFollowUp: Bool = true, assignedTo: String? = nil, urgency: Urgency = .medium) {
        self.id = id
        self.question = question
        self.context = context
        self.needsFollowUp = needsFollowUp
        self.assignedTo = assignedTo
        self.urgency = urgency
    }
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
    var actionItemsArray: [ActionItem] {
        get {
            guard let data = actionItems else { return [] }
            return (try? JSONDecoder().decode([ActionItem].self, from: data)) ?? []
        }
        set {
            actionItems = try? JSONEncoder().encode(newValue)
        }
    }
    
    var keyDecisionsArray: [KeyDecision] {
        get {
            guard let data = keyDecisions else { return [] }
            return (try? JSONDecoder().decode([KeyDecision].self, from: data)) ?? []
        }
        set {
            keyDecisions = try? JSONEncoder().encode(newValue)
        }
    }
    
    var questionsArray: [Question] {
        get {
            guard let data = questions else { return [] }
            return (try? JSONDecoder().decode([Question].self, from: data)) ?? []
        }
        set {
            questions = try? JSONEncoder().encode(newValue)
        }
    }
    
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