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
    case detectingColumns
    case extractingData
    case extractingCategories
    case aggregatingData
    case deduplicating
    case saving
    case complete
    
    var description: String {
        switch self {
        case .idle: return "Ready"
        case .readingFile: return "Reading file..."
        case .detectingColumns: return "Detecting columns..."
        case .extractingData: return "Extracting data..."
        case .extractingCategories: return "Extracting categories..."
        case .aggregatingData: return "Aggregating by category..."
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
    @Published var uniqueCategories: Set<String> = []
    @Published var categoryTotals: [String: Double] = [:]
    
    private let dataManager = DataManager.shared
    
    init() {
        // Don't load anything - files are not persistent
    }
    
    func importCSV(from url: URL) {
        Task {
            await importAndProcess(from: url)
        }
    }
    
    func clearImportedFiles() {
        importedFiles.removeAll()
        uniqueCategories.removeAll()
        categoryTotals.removeAll()
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
            processingMessage = "Adding \(url.lastPathComponent)..."
            let _ = try String(contentsOf: url, encoding: .utf8)
            print("✅ File validated: \(url.lastPathComponent)")
            processingProgress = 0.5
            
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
    
    // MARK: - Pipeline Implementation
    
    @MainActor
    func processAllFiles() async throws -> [Transaction] {
        guard !importedFiles.isEmpty else {
            throw ProcessingError.noFiles
        }
        
        isProcessing = true
        processingStep = .detectingColumns
        processingMessage = "Processing \(importedFiles.count) files..."
        processingProgress = 0.0
        
        var allTransactions: [ExtractedTransaction] = []
        uniqueCategories.removeAll()
        
        // Process each CSV file
        for (index, file) in importedFiles.enumerated() {
            guard file.url.startAccessingSecurityScopedResource() else { continue }
            defer { file.url.stopAccessingSecurityScopedResource() }
            
            let content = try String(contentsOf: file.url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            guard lines.count > 1 else { continue }
            
            // Step 1: Column Detection (assuming category column exists)
            processingMessage = "Detecting columns in \(file.name)..."
            let headers = parseCSVLine(lines[0])
            let columnMapping = try detectColumns(headers: headers)
            
            // Step 2: Data Extraction with Categories
            processingStep = .extractingData
            processingMessage = "Extracting data from \(file.name)..."
            let extractedTransactions = extractData(from: lines, using: columnMapping, headers: headers)
            
            // Collect unique categories
            for transaction in extractedTransactions {
                if let category = transaction.category {
                    uniqueCategories.insert(category)
                }
            }
            
            allTransactions.append(contentsOf: extractedTransactions)
            
            processingProgress = 0.3 * Double(index + 1) / Double(importedFiles.count)
            print("✅ Extracted \(extractedTransactions.count) transactions from \(file.name)")
        }
        
        print("📊 Total extracted: \(allTransactions.count) transactions")
        print("📂 Unique categories found: \(uniqueCategories.sorted())")
        
        // Step 3: Extract and Display Categories
        processingStep = .extractingCategories
        processingMessage = "Found \(uniqueCategories.count) unique categories..."
        processingProgress = 0.4
        
        // Step 4: Aggregate by Category
        processingStep = .aggregatingData
        processingMessage = "Aggregating by category..."
        processingProgress = 0.5
        
        categoryTotals = aggregateByCategory(transactions: allTransactions)
        print("💰 Category totals:")
        for (category, total) in categoryTotals.sorted(by: { $0.key < $1.key }) {
            print("   \(category): $\(String(format: "%.2f", total))")
        }
        
        // Step 5: Remove Duplicates (including transfers)
        processingStep = .deduplicating
        processingMessage = "Removing duplicates and transfers..."
        processingProgress = 0.7
        
        let uniqueTransactions = removeDuplicatesAndTransfers(from: allTransactions)
        print("✅ After deduplication: \(uniqueTransactions.count) unique transactions")
        
        // Step 6: Save to Database
        processingStep = .saving
        processingMessage = "Saving to database..."
        processingProgress = 0.9
        
        let transactions = createTransactionObjects(from: uniqueTransactions)
        try await dataManager.saveTransactions(transactions)
        
        self.parsedTransactions = transactions
        
        processingStep = .complete
        processingProgress = 1.0
        processingMessage = "Analysis complete: \(transactions.count) unique transactions in \(uniqueCategories.count) categories"
        
        print("✅ Processing complete!")
        print("📊 Summary:")
        print("   - Files processed: \(importedFiles.count)")
        print("   - Total extracted: \(allTransactions.count)")
        print("   - After deduplication: \(uniqueTransactions.count)")
        print("   - Categories found: \(uniqueCategories.count)")
        print("   - Saved: \(transactions.count)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.processingStep = .idle
            self?.isProcessing = false
        }
        
        return transactions
    }
    
    // MARK: - Step 1: Column Detection
    
    private struct ColumnMapping {
        var dateColumn: String?
        var amountColumn: String?
        var debitColumn: String?
        var creditColumn: String?
        var merchantColumn: String?
        var categoryColumn: String?
    }
    
    private func detectColumns(headers: [String]) throws -> ColumnMapping {
        var mapping = ColumnMapping()
        
        for header in headers {
            let lower = header.lowercased()
            
            // Date detection
            if mapping.dateColumn == nil && (
                lower.contains("date") ||
                lower == "posted" ||
                lower == "transaction date" ||
                lower == "trans date"
            ) {
                mapping.dateColumn = header
            }
            
            // Amount detection
            if mapping.amountColumn == nil && (
                lower == "amount" ||
                lower == "total" ||
                lower == "value" ||
                lower == "transaction amount"
            ) {
                mapping.amountColumn = header
            }
            
            // Debit detection
            if mapping.debitColumn == nil && (
                lower.contains("debit") ||
                lower == "withdrawal" ||
                lower == "money out"
            ) {
                mapping.debitColumn = header
            }
            
            // Credit detection  
            if mapping.creditColumn == nil && (
                lower.contains("credit") ||
                lower == "deposit" ||
                lower == "money in"
            ) {
                mapping.creditColumn = header
            }
            
            // Merchant detection
            if mapping.merchantColumn == nil && (
                lower.contains("description") ||
                lower.contains("merchant") ||
                lower.contains("payee") ||
                lower.contains("vendor") ||
                lower.contains("details") ||
                lower == "name" ||
                lower == "transaction description"
            ) {
                mapping.merchantColumn = header
            }
            
            // Category detection - REQUIRED
            if mapping.categoryColumn == nil && (
                lower.contains("category") ||
                lower.contains("type") ||
                lower == "transaction type" ||
                lower == "class" ||
                lower == "classification"
            ) {
                mapping.categoryColumn = header
            }
        }
        
        // Validate essential columns
        guard mapping.dateColumn != nil,
              mapping.merchantColumn != nil,
              (mapping.amountColumn != nil || (mapping.debitColumn != nil && mapping.creditColumn != nil)) else {
            throw ProcessingError.missingRequiredColumns("Missing required columns. Need: date, merchant, and amount (or debit/credit)")
        }
        
        // Check specifically for category column
        guard mapping.categoryColumn != nil else {
            throw ProcessingError.missingCategoryColumn("Error: Categories couldn't be identified. No 'Category' column found in CSV. Please ensure your CSV has a column named 'Category', 'Type', 'Transaction Type', 'Class', or 'Classification'.")
        }
        
        print("📊 Column mapping:")
        print("   Date: \(mapping.dateColumn ?? "not found")")
        print("   Amount: \(mapping.amountColumn ?? "not found")")
        print("   Debit: \(mapping.debitColumn ?? "not found")")
        print("   Credit: \(mapping.creditColumn ?? "not found")")
        print("   Merchant: \(mapping.merchantColumn ?? "not found")")
        print("   Category: \(mapping.categoryColumn ?? "not found") ✅")
        
        return mapping
    }
    
    // MARK: - Step 2: Data Extraction
    
    private struct ExtractedTransaction {
        let date: String
        let merchant: String
        let amount: Double
        let category: String?
    }
    
    private func extractData(from lines: [String], using mapping: ColumnMapping, headers: [String]) -> [ExtractedTransaction] {
        var transactions: [ExtractedTransaction] = []
        
        // Create header index map
        var headerIndex: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            headerIndex[header] = index
        }
        
        // Process each data row
        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            guard values.count == headers.count else { continue }
            
            // Extract date
            var date: String?
            if let dateCol = mapping.dateColumn, let idx = headerIndex[dateCol] {
                date = parseDate(values[idx])
            }
            
            // Extract merchant (with cleaning)
            var merchant: String?
            if let merchantCol = mapping.merchantColumn, let idx = headerIndex[merchantCol] {
                merchant = cleanMerchantName(values[idx])
            }
            
            // Calculate amount
            var amount: Double = 0
            if let amountCol = mapping.amountColumn, let idx = headerIndex[amountCol] {
                // Single amount column (preserve sign)
                amount = parseAmount(values[idx])
            } else {
                // Separate debit/credit columns
                if let debitCol = mapping.debitColumn, let idx = headerIndex[debitCol] {
                    let debitValue = parseAmount(values[idx])
                    if debitValue != 0 {
                        amount = -abs(debitValue) // Debits are always negative
                    }
                }
                if let creditCol = mapping.creditColumn, let idx = headerIndex[creditCol] {
                    let creditValue = parseAmount(values[idx])
                    if creditValue != 0 {
                        amount = abs(creditValue) // Credits are always positive
                    }
                }
            }
            
            // Extract category (REQUIRED)
            var category: String?
            if let categoryCol = mapping.categoryColumn, let idx = headerIndex[categoryCol] {
                let cat = values[idx].trimmingCharacters(in: .whitespaces)
                if !cat.isEmpty {
                    category = cat
                } else {
                    category = "Uncategorized" // Default for empty categories
                }
            }
            
            // Validate required fields
            guard let validDate = date,
                  let validMerchant = merchant,
                  !validMerchant.isEmpty,
                  amount != 0 else { continue }
            
            let transaction = ExtractedTransaction(
                date: validDate,
                merchant: validMerchant,
                amount: amount,
                category: category ?? "Uncategorized"
            )
            transactions.append(transaction)
            
            // Log extracted transaction
            print("📝 Row \(i): Date=\(validDate), Merchant=\(validMerchant), Amount=$\(String(format: "%.2f", amount)), Category=\(category ?? "Uncategorized")")
        }
        
        return transactions
    }
    
    private func cleanMerchantName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespaces)
        
        // Remove common prefixes
        let prefixes = [
            "Purchase at ",
            "Payment to ",
            "Transfer from ",
            "Transfer to ",
            "Direct Debit to ",
            "Card Payment to ",
            "POS Transaction at "
        ]
        
        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        
        // Remove transaction IDs and reference numbers (usually at the end)
        if let range = cleaned.range(of: #"\s+\d{6,}"#, options: .regularExpression) {
            cleaned = String(cleaned[..<range.lowerBound])
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Step 3: Aggregate by Category
    
    private func aggregateByCategory(transactions: [ExtractedTransaction]) -> [String: Double] {
        var totals: [String: Double] = [:]
        
        for transaction in transactions {
            let category = transaction.category ?? "Uncategorized"
            totals[category, default: 0] += transaction.amount
        }
        
        return totals
    }
    
    // MARK: - Step 4: Deduplication
    
    private func removeDuplicatesAndTransfers(from transactions: [ExtractedTransaction]) -> [ExtractedTransaction] {
        var seen = Set<String>()
        var unique: [ExtractedTransaction] = []
        
        // First pass: remove exact duplicates
        for transaction in transactions {
            let key = "\(transaction.date)|\(transaction.amount)|\(transaction.merchant)"
            
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(transaction)
            }
        }
        
        // Second pass: remove internal transfers
        // Look for pairs with same date, same category, and opposite amounts
        var indicesToRemove = Set<Int>()
        
        for i in 0..<unique.count {
            // Skip if already marked for removal
            if indicesToRemove.contains(i) { continue }
            
            for j in (i+1)..<unique.count {
                // Skip if already marked for removal
                if indicesToRemove.contains(j) { continue }
                
                let trans1 = unique[i]
                let trans2 = unique[j]
                
                // Check if they're matching transfers:
                // - Same date
                // - Same category
                // - Opposite amounts (one positive, one negative, same absolute value)
                if trans1.date == trans2.date && 
                   trans1.category == trans2.category &&
                   abs(trans1.amount + trans2.amount) < 0.01 { // Opposite amounts with same absolute value
                    indicesToRemove.insert(i)
                    indicesToRemove.insert(j)
                    print("🔄 DEDUP: Date=\(trans1.date), Category=\(trans1.category ?? "Unknown"), Amount1=$\(String(format: "%.2f", trans1.amount)), Amount2=$\(String(format: "%.2f", trans2.amount))")
                    print("         \(trans1.merchant) ↔ \(trans2.merchant)")
                }
            }
        }
        
        // Remove the identified transfer pairs
        let finalUnique = unique.enumerated().compactMap { index, transaction in
            indicesToRemove.contains(index) ? nil : transaction
        }
        
        print("🧹 Deduplication complete:")
        print("   - Original: \(transactions.count)")
        print("   - After exact duplicates: \(unique.count)")
        print("   - After transfer removal: \(finalUnique.count)")
        print("   - Internal transfers removed: \(indicesToRemove.count) transactions")
        
        return finalUnique
    }
    
    // MARK: - Step 5: Create Transaction Objects
    
    private func createTransactionObjects(from extractedTransactions: [ExtractedTransaction]) -> [Transaction] {
        return extractedTransactions.compactMap { extracted in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.date(from: extracted.date) ?? Date()
            
            return Transaction(
                date: date,
                amount: extracted.amount,
                description: extracted.merchant,
                counterparty: extracted.merchant,
                category: extracted.category ?? "Uncategorized"
            )
        }
    }
    
    // MARK: - Utility Functions
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        
        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }
    
    private func parseDate(_ value: String) -> String {
        let dateFormatters = [
            "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd",
            "MM-dd-yyyy", "M/d/yyyy", "d/M/yyyy"
        ]
        
        for format in dateFormatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "yyyy-MM-dd"
                return outputFormatter.string(from: date)
            }
        }
        
        // Fallback to current date
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd"
        return outputFormatter.string(from: Date())
    }
    
    private func parseAmount(_ value: String) -> Double {
        var cleanValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        cleanValue = cleanValue
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Double(cleanValue) ?? 0.0
    }
    
    // MARK: - Error Types
    
    enum ProcessingError: LocalizedError {
        case noFiles
        case missingRequiredColumns(String)
        case missingCategoryColumn(String)
        case parsingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noFiles:
                return "No CSV files have been imported. Please add files first."
            case .missingRequiredColumns(let reason):
                return "Missing required columns: \(reason)"
            case .missingCategoryColumn(let reason):
                return reason
            case .parsingFailed(let reason):
                return "Failed to parse CSV: \(reason)"
            }
        }
    }
}