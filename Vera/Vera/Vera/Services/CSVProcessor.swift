import Foundation
import CoreData

struct ImportedFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let importDate: Date
}

enum ProcessingStep {
    case idle
    case readingFile
    case parsing
    case categorizing
    case deduplicating
    case saving
    case complete
    
    var description: String {
        switch self {
        case .idle: return "Ready"
        case .readingFile: return "Reading file..."
        case .parsing: return "Parsing CSV with AI..."
        case .categorizing: return "Categorizing transactions..."
        case .deduplicating: return "Removing duplicates..."
        case .saving: return "Saving to database..."
        case .complete: return "Complete"
        }
    }
}

class CSVProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var importedFiles: [ImportedFile] = []
    @Published var parsedTransactions: [Transaction] = []
    @Published var processingStep: ProcessingStep = .idle
    @Published var processingProgress: Double = 0.0
    @Published var processingMessage: String = ""
    
    private let lfm2Service = LFM2Service.shared
    private let dataManager = DataManager.shared
    
    func importCSV(from url: URL) {
        Task {
            await importAndProcess(from: url)
        }
    }
    
    @MainActor
    func importAndProcess(from url: URL) async {
        print("📁 Starting CSV import and processing: \(url.lastPathComponent)")
        isProcessing = true
        errorMessage = nil
        processingStep = .readingFile
        processingProgress = 0.0
        
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access the selected file: \(url.lastPathComponent)"
            isProcessing = false
            processingStep = .idle
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            // Step 1: Read file
            processingMessage = "Reading \(url.lastPathComponent)..."
            let content = try String(contentsOf: url, encoding: .utf8)
            print("✅ File read successfully. Size: \(content.count) characters")
            processingProgress = 0.1
            
            // Store the imported file record
            let importedFile = ImportedFile(
                name: url.lastPathComponent,
                url: url,
                importDate: Date()
            )
            importedFiles.append(importedFile)
            
            // Step 2: Parse CSV with LFM2
            processingStep = .parsing
            processingMessage = "Parsing CSV with AI..."
            processingProgress = 0.2
            
            let parsedData = try await lfm2Service.parseCSV(content)
            print("✅ Parsed \(parsedData.count) transactions")
            processingProgress = 0.4
            
            // Step 3: Categorize transactions
            processingStep = .categorizing
            processingMessage = "Categorizing \(parsedData.count) transactions..."
            processingProgress = 0.5
            
            var categorizedData: [[String: Any]] = []
            for (index, transaction) in parsedData.enumerated() {
                var mutableTransaction = transaction
                
                // Extract transaction details for categorization
                let description = transaction["description"] as? String ?? ""
                let merchant = transaction["counterparty"] as? String ?? description
                
                // Get category from LFM2
                if !merchant.isEmpty {
                    let category = try await lfm2Service.categorizeTransaction(merchant)
                    mutableTransaction["category"] = category
                } else {
                    mutableTransaction["category"] = "Other"
                }
                
                categorizedData.append(mutableTransaction)
                processingProgress = 0.5 + (0.2 * Double(index + 1) / Double(parsedData.count))
            }
            
            print("✅ Categorized \(categorizedData.count) transactions")
            
            // Step 4: Deduplicate
            processingStep = .deduplicating
            processingMessage = "Removing duplicates and transfers..."
            processingProgress = 0.7
            
            let uniqueData = try await lfm2Service.deduplicateTransactions(categorizedData)
            print("✅ After deduplication: \(uniqueData.count) unique transactions")
            processingProgress = 0.8
            
            // Step 5: Create Transaction objects
            processingStep = .saving
            processingMessage = "Saving to database..."
            processingProgress = 0.9
            
            let transactions = createTransactionObjects(from: uniqueData)
            
            // Step 6: Save to Core Data
            try await dataManager.saveTransactions(transactions)
            
            // Update parsed transactions for display
            self.parsedTransactions = transactions
            
            processingStep = .complete
            processingProgress = 1.0
            processingMessage = "Import complete: \(transactions.count) transactions"
            
            print("✅ Import complete!")
            print("📊 Summary:")
            print("   - File: \(url.lastPathComponent)")
            print("   - Original: \(parsedData.count) transactions")
            print("   - After deduplication: \(uniqueData.count) transactions")
            print("   - Saved: \(transactions.count) transactions")
            
            // Reset after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.processingStep = .idle
                self.isProcessing = false
            }
            
        } catch {
            print("❌ Import failed: \(error)")
            errorMessage = "Failed to process \(url.lastPathComponent): \(error.localizedDescription)"
            processingStep = .idle
            isProcessing = false
        }
    }
    
    private func createTransactionObjects(from data: [[String: Any]]) -> [Transaction] {
        return data.compactMap { dict in
            guard let dateString = dict["date"] as? String,
                  let amount = dict["amount"] as? Double else {
                return nil
            }
            
            // Parse date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.date(from: dateString) ?? Date()
            
            return Transaction(
                id: UUID(),
                date: date,
                description: dict["description"] as? String ?? "",
                amount: amount,
                category: dict["category"] as? String,
                counterparty: dict["counterparty"] as? String
            )
        }
    }
}