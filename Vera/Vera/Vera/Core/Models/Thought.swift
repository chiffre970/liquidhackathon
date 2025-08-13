import Foundation
import CoreData

@objc(Thought)
public class Thought: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var rawTranscription: String
    @NSManaged public var summary: String
    @NSManaged public var categoryData: Data?
    @NSManaged public var sessionId: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var tags: String?
    
    var category: Category? {
        get {
            guard let data = categoryData else { return nil }
            return try? JSONDecoder().decode(Category.self, from: data)
        }
        set {
            categoryData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var tagsArray: [String] {
        get {
            guard let tags = tags else { return [] }
            return tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.joined(separator: ", ")
        }
    }
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        timestamp = Date()
    }
}

extension Thought {
    static func fetchRequest() -> NSFetchRequest<Thought> {
        return NSFetchRequest<Thought>(entityName: "Thought")
    }
    
    static func fetchRequestForSession(_ sessionId: UUID) -> NSFetchRequest<Thought> {
        let request = NSFetchRequest<Thought>(entityName: "Thought")
        request.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Thought.timestamp, ascending: true)]
        return request
    }
    
    static func fetchActionsRequest() -> NSFetchRequest<Thought> {
        let request = NSFetchRequest<Thought>(entityName: "Thought")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Thought.timestamp, ascending: false)]
        return request
    }
}