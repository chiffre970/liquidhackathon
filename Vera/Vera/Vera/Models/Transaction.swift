import Foundation

struct Transaction: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var amount: Double
    var description: String
    var counterparty: String?
    var category: String?
    var isAnalyzed: Bool = false
    
    init(date: Date, amount: Double, description: String, counterparty: String? = nil, category: String? = nil) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.description = description
        self.counterparty = counterparty
        self.category = category
    }
}