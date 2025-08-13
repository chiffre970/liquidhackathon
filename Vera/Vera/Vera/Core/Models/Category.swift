import Foundation

enum Category: Codable {
    case action(deadline: Date?, priority: Priority)
    case thought(theme: String)
    
    enum Priority: String, Codable {
        case high = "high"
        case medium = "medium"
        case low = "low"
    }
    
    var isAction: Bool {
        if case .action = self {
            return true
        }
        return false
    }
    
    var displayName: String {
        switch self {
        case .action:
            return "Action"
        case .thought:
            return "Thought"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case deadline
        case priority
        case theme
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "action":
            let deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
            let priority = try container.decode(Priority.self, forKey: .priority)
            self = .action(deadline: deadline, priority: priority)
        case "thought":
            let theme = try container.decode(String.self, forKey: .theme)
            self = .thought(theme: theme)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown category type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .action(let deadline, let priority):
            try container.encode("action", forKey: .type)
            try container.encodeIfPresent(deadline, forKey: .deadline)
            try container.encode(priority, forKey: .priority)
        case .thought(let theme):
            try container.encode("thought", forKey: .type)
            try container.encode(theme, forKey: .theme)
        }
    }
}