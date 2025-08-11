import Foundation

struct Budget: Identifiable, Codable {
    let id: UUID
    let monthlyTarget: Double
    let categories: [CategoryAllocation]
    let changes: [String]
    let createdDate: Date
    
    struct CategoryAllocation: Codable {
        let name: String
        let amount: Double
        let percentage: Double
    }
    
    var totalAllocated: Double {
        categories.reduce(0) { $0 + $1.amount }
    }
    
    var isBalanced: Bool {
        abs(totalAllocated - monthlyTarget) < 1.0
    }
}