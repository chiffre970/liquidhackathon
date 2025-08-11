import Foundation

struct CashFlowData {
    let income: Double
    let expenses: Double
    let categories: [Category]
    let analysis: String?
    
    struct Category {
        let name: String
        let amount: Double
        let percentage: Double
    }
    
    var netFlow: Double {
        income - expenses
    }
    
    var savingsRate: Double {
        guard income > 0 else { return 0 }
        return (netFlow / income) * 100
    }
}