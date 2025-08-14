import Foundation
import CoreData

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
    @NSManaged public var audioFileURL: String?
}

extension Meeting: Identifiable {
    
}

struct ActionItem: Codable {
    let id: UUID
    let task: String
    let owner: String?
    let deadline: Date?
    let isCompleted: Bool
    
    init(id: UUID = UUID(), task: String, owner: String? = nil, deadline: Date? = nil, isCompleted: Bool = false) {
        self.id = id
        self.task = task
        self.owner = owner
        self.deadline = deadline
        self.isCompleted = isCompleted
    }
}

struct KeyDecision: Codable {
    let id: UUID
    let decision: String
    let context: String?
    let timestamp: Date
    
    init(id: UUID = UUID(), decision: String, context: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.decision = decision
        self.context = context
        self.timestamp = timestamp
    }
}

struct Question: Codable {
    let id: UUID
    let question: String
    let context: String?
    let needsFollowUp: Bool
    
    init(id: UUID = UUID(), question: String, context: String? = nil, needsFollowUp: Bool = false) {
        self.id = id
        self.question = question
        self.context = context
        self.needsFollowUp = needsFollowUp
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
    
    var audioURL: URL? {
        guard let audioFileURL = audioFileURL else { return nil }
        return URL(string: audioFileURL)
    }
}