import Foundation
import CoreData
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var transactions: [Transaction] = []
    @Published var budgets: [Budget] = []
    @Published var isLoading = false
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        loadTransactions()
    }
    
    func saveTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        saveToUserDefaults()
    }
    
    func updateTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            saveToUserDefaults()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveToUserDefaults()
    }
    
    func clearAllTransactions() {
        transactions.removeAll()
        UserDefaults.standard.removeObject(forKey: "vera_transactions")
    }
    
    func importTransactions(_ newTransactions: [Transaction]) async {
        await MainActor.run {
            isLoading = true
        }
        
        for transaction in newTransactions {
            if transaction.category == nil {
                var categorizedTransaction = transaction
                do {
                    categorizedTransaction.category = try await LFM2Manager.shared.categorizeTransaction(transaction.description)
                    categorizedTransaction.isAnalyzed = true
                } catch {
                    // If categorization fails, mark as "Other" and log the error
                    print("Failed to categorize transaction: \(error)")
                    categorizedTransaction.category = "Other"
                    categorizedTransaction.isAnalyzed = false
                }
                transactions.append(categorizedTransaction)
            } else {
                transactions.append(transaction)
            }
        }
        
        await MainActor.run {
            saveToUserDefaults()
            isLoading = false
        }
    }
    
    func saveTransactions(_ newTransactions: [Transaction]) async throws {
        print("💾 DataManager: Attempting to save \(newTransactions.count) new transactions")
        print("💾 DataManager: Current transaction count before save: \(transactions.count)")
        
        await MainActor.run {
            isLoading = true
        }
        
        var savedCount = 0
        var duplicateCount = 0
        
        // Check for duplicates before adding
        for transaction in newTransactions {
            // Check if transaction already exists based on date, amount, and description
            let isDuplicate = transactions.contains { existing in
                existing.date == transaction.date &&
                existing.amount == transaction.amount &&
                existing.description == transaction.description
            }
            
            if !isDuplicate {
                transactions.append(transaction)
                savedCount += 1
                print("   ✅ Saved: \(transaction.description) - $\(transaction.amount) on \(transaction.date)")
            } else {
                duplicateCount += 1
                print("   ⚠️ Duplicate skipped: \(transaction.description) - $\(transaction.amount)")
            }
        }
        
        print("💾 DataManager: Save results - Saved: \(savedCount), Duplicates: \(duplicateCount)")
        print("💾 DataManager: Total transaction count after save: \(transactions.count)")
        
        await MainActor.run {
            // Sort transactions by date
            transactions.sort { $0.date > $1.date }
            saveToUserDefaults()
            print("💾 DataManager: Persisted to UserDefaults")
            isLoading = false
        }
    }
    
    func fetchTransactions(for month: Date) -> [Transaction] {
        return getTransactions(for: month)
    }
    
    func saveBudget(_ budget: Budget) {
        budgets.append(budget)
        saveBudgetsToUserDefaults()
    }
    
    func getCurrentBudget() -> Budget? {
        return budgets.sorted { $0.createdDate > $1.createdDate }.first
    }
    
    func getTransactions(for month: Date) -> [Transaction] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: month)?.start ?? Date()
        let endOfMonth = calendar.dateInterval(of: .month, for: month)?.end ?? Date()
        
        let filtered = transactions.filter { transaction in
            transaction.date >= startOfMonth && transaction.date < endOfMonth
        }
        
        print("📅 DataManager: Filtering for month \(month)")
        print("   - Total transactions: \(transactions.count)")
        print("   - Filtered transactions: \(filtered.count)")
        print("   - Date range: \(startOfMonth) to \(endOfMonth)")
        
        return filtered
    }
    
    private func loadTransactions() {
        if let data = UserDefaults.standard.data(forKey: "vera_transactions"),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            self.transactions = decoded
            print("💾 DataManager: Loaded \(decoded.count) transactions from UserDefaults")
        } else {
            print("💾 DataManager: No existing transactions found in UserDefaults")
        }
    }
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(encoded, forKey: "vera_transactions")
        }
    }
    
    private func saveBudgetsToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(budgets) {
            UserDefaults.standard.set(encoded, forKey: "vera_budgets")
        }
    }
    
    func clearAllData() {
        transactions.removeAll()
        budgets.removeAll()
        UserDefaults.standard.removeObject(forKey: "vera_transactions")
        UserDefaults.standard.removeObject(forKey: "vera_budgets")
    }
}