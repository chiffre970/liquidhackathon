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
    case mappingCategories
    case categorizingTransactions
    case deduplicating
    case saving
    case complete
    
    var description: String {
        switch self {
        case .idle: return "Ready"
        case .readingFile: return "Reading file..."
        case .detectingColumns: return "Detecting columns..."
        case .extractingData: return "Extracting data..."
        case .mappingCategories: return "Mapping categories..."
        case .categorizingTransactions: return "Categorizing transactions..."
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
    
    // Cache for merchant → category mappings
    private var merchantCategoryCache: [String: String] = [:]
    
    // Standard categories for the app
    private let standardCategories = [
        "Food & Dining",
        "Transportation", 
        "Healthcare",
        "Entertainment",
        "Shopping",
        "Utilities",
        "Education",
        "Insurance",
        "Personal Care",
        "Gifts & Donations",
        "Business Services",
        "Fees & Charges",
        "Income",
        "Housing",
        "Savings",
        "Investment",
        "Travel",
        "Other"
    ]
    
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
        
        print("🤖 Initializing LFM2 model...")
        await lfm2Service.initialize()
        
        isProcessing = true
        processingStep = .detectingColumns
        processingMessage = "Processing \(importedFiles.count) files..."
        processingProgress = 0.0
        
        var allTransactions: [ExtractedTransaction] = []
        
        // Process each CSV file
        for (index, file) in importedFiles.enumerated() {
            guard file.url.startAccessingSecurityScopedResource() else { continue }
            defer { file.url.stopAccessingSecurityScopedResource() }
            
            let content = try String(contentsOf: file.url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            guard lines.count > 1 else { continue }
            
            // Step 1: Smart Column Detection
            processingMessage = "Detecting columns in \(file.name)..."
            let headers = parseCSVLine(lines[0])
            let sampleRow = lines.count > 1 ? parseCSVLine(lines[1]) : []
            let columnMapping = try await detectColumns(headers: headers, sampleRow: sampleRow)
            
            // Step 2: Data Extraction
            processingStep = .extractingData
            processingMessage = "Extracting data from \(file.name)..."
            let extractedTransactions = extractData(from: lines, using: columnMapping, headers: headers)
            allTransactions.append(contentsOf: extractedTransactions)
            
            processingProgress = 0.3 * Double(index + 1) / Double(importedFiles.count)
            print("✅ Extracted \(extractedTransactions.count) transactions from \(file.name)")
        }
        
        print("📊 Total extracted: \(allTransactions.count) transactions")
        
        // Step 3: Category Standardization
        processingStep = .mappingCategories
        processingMessage = "Standardizing categories..."
        processingProgress = 0.3
        
        let (transactionsWithMappedCategories, _) = try await standardizeCategories(transactions: allTransactions)
        
        // Step 4: AI Categorization for transactions without categories
        processingStep = .categorizingTransactions
        processingMessage = "Categorizing transactions..."
        processingProgress = 0.5
        
        let categorizedTransactions = try await categorizeTransactions(transactionsWithMappedCategories)
        
        // Step 5: Remove Duplicates
        processingStep = .deduplicating
        processingMessage = "Removing duplicates..."
        processingProgress = 0.7
        
        let uniqueTransactions = removeDuplicates(from: categorizedTransactions)
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
        processingMessage = "Analysis complete: \(transactions.count) unique transactions"
        
        print("✅ Processing complete!")
        print("📊 Summary:")
        print("   - Files processed: \(importedFiles.count)")
        print("   - Total extracted: \(allTransactions.count)")
        print("   - After deduplication: \(uniqueTransactions.count)")
        print("   - Saved: \(transactions.count)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.processingStep = .idle
            self?.isProcessing = false
        }
        
        return transactions
    }
    
    // MARK: - Step 1: Smart Column Detection
    
    private struct ColumnMapping {
        var dateColumn: String?
        var amountColumn: String?
        var debitColumn: String?
        var creditColumn: String?
        var merchantColumn: String?
        var categoryColumn: String?
    }
    
    private func detectColumns(headers: [String], sampleRow: [String]) async throws -> ColumnMapping {
        // Fast Path: Try pattern matching first
        let fastMapping = detectColumnsFastPath(headers: headers)
        
        // If we found essential columns, use fast path
        if fastMapping.dateColumn != nil && 
           (fastMapping.amountColumn != nil || (fastMapping.debitColumn != nil && fastMapping.creditColumn != nil)) &&
           fastMapping.merchantColumn != nil {
            print("✅ Fast path column detection successful")
            return fastMapping
        }
        
        // AI Path: Use LFM2 for unusual formats
        print("🤖 Using AI for column detection...")
        return try await detectColumnsWithAI(headers: headers, sampleRow: sampleRow)
    }
    
    private func detectColumnsFastPath(headers: [String]) -> ColumnMapping {
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
            
            // Category detection
            if mapping.categoryColumn == nil && (
                lower.contains("category") ||
                lower.contains("type") ||
                lower == "transaction type"
            ) {
                mapping.categoryColumn = header
            }
        }
        
        print("📊 Fast path mapping:")
        print("   Date: \(mapping.dateColumn ?? "not found")")
        print("   Amount: \(mapping.amountColumn ?? "not found")")
        print("   Debit: \(mapping.debitColumn ?? "not found")")
        print("   Credit: \(mapping.creditColumn ?? "not found")")
        print("   Merchant: \(mapping.merchantColumn ?? "not found")")
        print("   Category: \(mapping.categoryColumn ?? "not found")")
        
        return mapping
    }
    
    private func detectColumnsWithAI(headers: [String], sampleRow: [String]) async throws -> ColumnMapping {
        let headerList = headers.joined(separator: ", ")
        let sampleData = sampleRow.joined(separator: ", ")
        
        let prompt = """
        Analyze these CSV headers and identify which columns contain transaction data.
        
        Headers: \(headerList)
        Sample row: \(sampleData)
        
        Identify columns for:
        - date: transaction date
        - merchant: merchant/vendor/description
        - amount: single amount column (with +/- for income/expense)
        - debit: separate debit/withdrawal column (if no single amount)
        - credit: separate credit/deposit column (if no single amount)
        - category: transaction category (may not exist)
        
        IMPORTANT: Banks use EITHER single "amount" OR separate "debit/credit", never both.
        Return null for columns that don't exist.
        
        Respond with ONLY this JSON format:
        {"date": "header_name", "merchant": "header_name", "amount": null, "debit": "header_name", "credit": "header_name", "category": null}
        
        Use exact header names from the list. Use null if column doesn't exist.
        """
        
        let response = try await lfm2Service.inference(prompt, type: "ColumnDetector")
        
        // Parse JSON response
        guard let jsonData = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ProcessingError.parsingFailed("Failed to parse column detection response")
        }
        
        var mapping = ColumnMapping()
        mapping.dateColumn = json["date"] as? String
        mapping.merchantColumn = json["merchant"] as? String
        mapping.amountColumn = json["amount"] as? String
        mapping.debitColumn = json["debit"] as? String
        mapping.creditColumn = json["credit"] as? String
        mapping.categoryColumn = json["category"] as? String
        
        // Validate essential columns
        guard mapping.dateColumn != nil,
              mapping.merchantColumn != nil,
              (mapping.amountColumn != nil || (mapping.debitColumn != nil && mapping.creditColumn != nil)) else {
            throw ProcessingError.parsingFailed("Missing essential columns (date, merchant, amount)")
        }
        
        print("✅ AI column detection successful")
        return mapping
    }
    
    // MARK: - Step 2: Data Extraction
    
    private struct ExtractedTransaction {
        let date: String
        let merchant: String
        let amount: Double
        var category: String?
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
            
            // Extract category (optional)
            var category: String?
            if let categoryCol = mapping.categoryColumn, let idx = headerIndex[categoryCol] {
                let cat = values[idx].trimmingCharacters(in: .whitespaces)
                if !cat.isEmpty {
                    category = cat
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
                category: category
            )
            transactions.append(transaction)
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
    
    // MARK: - Step 3: Category Standardization
    
    private func standardizeCategories(transactions: [ExtractedTransaction]) async throws -> ([ExtractedTransaction], [String: String]) {
        // Extract unique CSV categories
        let csvCategories = Set(transactions.compactMap { $0.category })
        
        guard !csvCategories.isEmpty else {
            // No categories in CSV, return as-is
            return (transactions, [:])
        }
        
        print("📊 Found \(csvCategories.count) unique categories in CSV")
        
        // Map to standard categories
        let categoryMapping = try await mapToStandardCategories(csvCategories: Array(csvCategories))
        
        // Apply mapping to transactions
        var mappedTransactions: [ExtractedTransaction] = []
        for transaction in transactions {
            var updated = transaction
            if let csvCategory = transaction.category,
               let standardCategory = categoryMapping[csvCategory] {
                updated.category = standardCategory
            }
            mappedTransactions.append(updated)
        }
        
        return (mappedTransactions, categoryMapping)
    }
    
    private func mapToStandardCategories(csvCategories: [String]) async throws -> [String: String] {
        // Build batch prompt for efficiency
        let prompt = """
        Map each CSV category to the best matching standard category.
        
        Standard categories: \(standardCategories.joined(separator: ", "))
        
        CSV categories to map:
        \(csvCategories.map { "- \($0)" }.joined(separator: "\n"))
        
        Return ONLY a JSON object mapping each CSV category to a standard category:
        {"csv_category": "standard_category", ...}
        
        Use exact spelling from standard categories. When unsure, use "Other".
        """
        
        let response = try await lfm2Service.inference(prompt, type: "CategoryMapper")
        
        guard let jsonData = extractJSON(from: response),
              let mapping = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
            // Fallback to heuristic mapping
            return heuristicCategoryMapping(csvCategories: csvCategories)
        }
        
        print("✅ Mapped \(mapping.count) categories to standards")
        return mapping
    }
    
    private func heuristicCategoryMapping(csvCategories: [String]) -> [String: String] {
        var mapping: [String: String] = [:]
        
        for category in csvCategories {
            let lower = category.lowercased()
            
            if lower.contains("food") || lower.contains("dining") || lower.contains("restaurant") {
                mapping[category] = "Food & Dining"
            } else if lower.contains("transport") || lower.contains("fuel") || lower.contains("uber") {
                mapping[category] = "Transportation"
            } else if lower.contains("health") || lower.contains("medical") || lower.contains("pharmacy") {
                mapping[category] = "Healthcare"
            } else if lower.contains("entertainment") || lower.contains("movie") || lower.contains("game") {
                mapping[category] = "Entertainment"
            } else if lower.contains("shop") || lower.contains("retail") || lower.contains("store") {
                mapping[category] = "Shopping"
            } else if lower.contains("utilit") || lower.contains("electric") || lower.contains("water") {
                mapping[category] = "Utilities"
            } else if lower.contains("income") || lower.contains("salary") || lower.contains("deposit") {
                mapping[category] = "Income"
            } else {
                mapping[category] = "Other"
            }
        }
        
        return mapping
    }
    
    // MARK: - Step 4: AI Categorization
    
    private func categorizeTransactions(_ transactions: [ExtractedTransaction]) async throws -> [ExtractedTransaction] {
        // Filter transactions without categories
        let uncategorized = transactions.enumerated().filter { $0.element.category == nil }
        
        if uncategorized.isEmpty {
            print("✅ All transactions already have categories")
            return transactions
        }
        
        print("🤖 Categorizing \(uncategorized.count) transactions...")
        
        var result = transactions
        let batchSize = 10
        
        // Process in batches for efficiency
        for i in stride(from: 0, to: uncategorized.count, by: batchSize) {
            let endIndex = min(i + batchSize, uncategorized.count)
            let batch = Array(uncategorized[i..<endIndex])
            
            // Check cache first
            var cached: [(Int, String)] = []
            var needsAI: [(Int, ExtractedTransaction)] = []
            
            for (idx, transaction) in batch {
                if let cachedCategory = merchantCategoryCache[transaction.merchant] {
                    cached.append((idx, cachedCategory))
                } else {
                    needsAI.append((idx, transaction))
                }
            }
            
            // Apply cached categories
            for (idx, category) in cached {
                result[idx].category = category
            }
            
            // Process uncached with AI
            if !needsAI.isEmpty {
                let categories = try await categorizeBatch(needsAI.map { $0.1 })
                
                for ((idx, transaction), category) in zip(needsAI, categories) {
                    result[idx].category = category
                    // Update cache
                    merchantCategoryCache[transaction.merchant] = category
                }
            }
            
            processingProgress = 0.5 + (0.2 * Double(i + batch.count) / Double(uncategorized.count))
        }
        
        return result
    }
    
    private func categorizeBatch(_ transactions: [ExtractedTransaction]) async throws -> [String] {
        let transactionList = transactions.map { 
            "Merchant: \($0.merchant), Amount: $\(String(format: "%.2f", abs($0.amount))) \($0.amount < 0 ? "expense" : "income")"
        }.joined(separator: "\n")
        
        let prompt = """
        Categorize these transactions into standard categories.
        
        Standard categories: \(standardCategories.joined(separator: ", "))
        
        Transactions:
        \(transactionList)
        
        Return ONLY a JSON array with one category per transaction in order:
        ["category1", "category2", ...]
        
        Use exact category names from the standard list.
        """
        
        let response = try await lfm2Service.inference(prompt, type: "BatchCategorizer")
        
        guard let jsonData = extractJSON(from: response),
              let categories = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            // Fallback to individual categorization
            var categories: [String] = []
            for transaction in transactions {
                let category = try await lfm2Service.categorizeTransaction(transaction.merchant)
                categories.append(category)
            }
            return categories
        }
        
        // Ensure we have the right number of categories
        guard categories.count == transactions.count else {
            print("⚠️ Category count mismatch, falling back to individual categorization")
            var fallbackCategories: [String] = []
            for transaction in transactions {
                let category = try await lfm2Service.categorizeTransaction(transaction.merchant)
                fallbackCategories.append(category)
            }
            return fallbackCategories
        }
        
        return categories
    }
    
    // MARK: - Step 5: Deduplication
    
    private func removeDuplicates(from transactions: [ExtractedTransaction]) -> [ExtractedTransaction] {
        var seen = Set<String>()
        var unique: [ExtractedTransaction] = []
        
        for transaction in transactions {
            let key = "\(transaction.date)|\(transaction.amount)|\(transaction.merchant)"
            
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(transaction)
            }
        }
        
        return unique
    }
    
    // MARK: - Step 6: Create Transaction Objects
    
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
                category: extracted.category ?? "Other"
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
    
    private func extractJSON(from response: String) -> Data? {
        // Find JSON object or array in response
        let patterns = [
            (#"\{[^}]*\}"#, true),  // JSON object
            (#"\[[^\]]*\]"#, true)  // JSON array
        ]
        
        for (pattern, _) in patterns {
            if let range = response.range(of: pattern, options: .regularExpression) {
                let jsonString = String(response[range])
                return jsonString.data(using: .utf8)
            }
        }
        
        // Try the whole response
        return response.data(using: .utf8)
    }
    
    // MARK: - Error Types
    
    enum ProcessingError: LocalizedError {
        case noFiles
        case parsingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noFiles:
                return "No CSV files have been imported. Please add files first."
            case .parsingFailed(let reason):
                return "Failed to parse CSV: \(reason)"
            }
        }
    }
}