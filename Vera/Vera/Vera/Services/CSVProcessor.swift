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
        print("📁 Adding CSV file: \(url.lastPathComponent)")
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
            // Just validate and store the file
            processingMessage = "Adding \(url.lastPathComponent)..."
            let _ = try String(contentsOf: url, encoding: .utf8)
            print("✅ File validated: \(url.lastPathComponent)")
            processingProgress = 0.5
            
            // Store the imported file record
            let importedFile = ImportedFile(
                name: url.lastPathComponent,
                url: url,
                importDate: Date()
            )
            importedFiles.append(importedFile)
            
            processingStep = .complete
            processingProgress = 1.0
            processingMessage = "File added: \(url.lastPathComponent)"
            
            print("✅ File stored successfully!")
            print("📊 Total files ready for analysis: \(importedFiles.count)")
            
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
    
    // Process ALL imported files when Analyze is clicked
    @MainActor
    func processAllFiles() async throws -> [Transaction] {
        guard !importedFiles.isEmpty else {
            throw ProcessingError.noFiles
        }
        
        // Initialize the model first
        print("🤖 Initializing LFM2 model...")
        await lfm2Service.initialize()
        
        isProcessing = true
        processingStep = .parsing
        processingMessage = "Processing \(importedFiles.count) files..."
        processingProgress = 0.0
        
        var allParsedData: [[String: Any]] = []
        
        // Step 1: Parse all CSV files
        for (index, file) in importedFiles.enumerated() {
            guard file.url.startAccessingSecurityScopedResource() else { continue }
            defer { file.url.stopAccessingSecurityScopedResource() }
            
            let content = try String(contentsOf: file.url, encoding: .utf8)
            let parsedData = try await lfm2Service.parseCSV(content)
            allParsedData.append(contentsOf: parsedData)
            
            processingProgress = 0.3 * Double(index + 1) / Double(importedFiles.count)
            processingMessage = "Parsed \(file.name): \(parsedData.count) transactions"
            print("✅ Parsed \(file.name): \(parsedData.count) transactions")
        }
        
        print("✅ Total parsed: \(allParsedData.count) transactions from \(importedFiles.count) files")
        
        // Step 2: Categorize all transactions
        processingStep = .categorizing
        processingMessage = "Categorizing \(allParsedData.count) transactions..."
        processingProgress = 0.3
        
        var categorizedData: [[String: Any]] = []
        for (index, transaction) in allParsedData.enumerated() {
            var mutableTransaction = transaction
            let description = transaction["description"] as? String ?? ""
            let merchant = transaction["counterparty"] as? String ?? description
            
            if !merchant.isEmpty {
                let category = try await lfm2Service.categorizeTransaction(merchant)
                mutableTransaction["category"] = category
            } else {
                mutableTransaction["category"] = "Other"
            }
            
            categorizedData.append(mutableTransaction)
            processingProgress = 0.3 + (0.3 * Double(index + 1) / Double(allParsedData.count))
        }
        
        print("✅ Categorized: \(categorizedData.count) transactions")
        
        // Step 3: Deduplicate across ALL transactions
        processingStep = .deduplicating
        processingMessage = "Removing duplicates across all files..."
        processingProgress = 0.6
        
        let uniqueData = try await lfm2Service.deduplicateTransactions(categorizedData)
        print("✅ After deduplication: \(uniqueData.count) unique transactions")
        processingProgress = 0.8
        
        // Step 4: Create Transaction objects and save
        processingStep = .saving
        processingMessage = "Saving to database..."
        processingProgress = 0.9
        
        let transactions = createTransactionObjects(from: uniqueData)
        try await dataManager.saveTransactions(transactions)
        
        self.parsedTransactions = transactions
        
        processingStep = .complete
        processingProgress = 1.0
        processingMessage = "Analysis complete: \(transactions.count) unique transactions"
        
        print("✅ Processing complete!")
        print("📊 Summary:")
        print("   - Files processed: \(importedFiles.count)")
        print("   - Total parsed: \(allParsedData.count)")
        print("   - After deduplication: \(uniqueData.count)")
        print("   - Saved: \(transactions.count)")
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.processingStep = .idle
            self.isProcessing = false
        }
        
        return transactions
    }
    
    enum ProcessingError: LocalizedError {
        case noFiles
        
        var errorDescription: String? {
            switch self {
            case .noFiles:
                return "No CSV files have been imported. Please add files first."
            }
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
                date: date,
                amount: amount,
                description: dict["description"] as? String ?? "",
                counterparty: dict["counterparty"] as? String,
                category: dict["category"] as? String
            )
        }
    }
}