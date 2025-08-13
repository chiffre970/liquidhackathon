import Foundation
import CoreData

@objc(Session)
public class Session: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var overallSummary: String?
    @NSManaged public var thoughtCount: Int32
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        startTime = Date()
        thoughtCount = 0
    }
}

extension Session {
    static func fetchRequest() -> NSFetchRequest<Session> {
        return NSFetchRequest<Session>(entityName: "Session")
    }
    
    static func fetchRecentSessions(limit: Int = 10) -> NSFetchRequest<Session> {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Session.startTime, ascending: false)]
        request.fetchLimit = limit
        return request
    }
    
    static func createNew(in context: NSManagedObjectContext) -> Session {
        let session = Session(context: context)
        return session
    }
    
    func end() {
        endTime = Date()
    }
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}