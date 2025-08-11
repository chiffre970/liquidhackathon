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
    
    init() {
        // Don't load anything - files are not persistent
    }
    
    func importCSV(from url: URL) {
        Task {
            await importAndProcess(from: url)
        }
    }
    
    // Clear imported files
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
            // Don't persist files - they're session-only
            
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
        
        // Step 1: Parse all CSV files using LFM2 intelligent parsing
        for (index, file) in importedFiles.enumerated() {
            guard file.url.startAccessingSecurityScopedResource() else { continue }
            defer { file.url.stopAccessingSecurityScopedResource() }
            
            let content = try String(contentsOf: file.url, encoding: .utf8)
            let parsedData = try await parseCSVWithLFM2(content)
            allParsedData.append(contentsOf: parsedData)
            
            processingProgress = 0.3 * Double(index + 1) / Double(importedFiles.count)
            processingMessage = "Parsed \(file.name): \(parsedData.count) transactions"
            print("✅ Parsed \(file.name): \(parsedData.count) transactions")
        }
        
        print("✅ Total parsed: \(allParsedData.count) transactions from \(importedFiles.count) files")
        
        // Step 2: Categorize transactions that don't have categories yet
        processingStep = .categorizing
        processingMessage = "Categorizing transactions..."
        processingProgress = 0.3
        
        var categorizedData: [[String: Any]] = []
        for (index, transaction) in allParsedData.enumerated() {
            var mutableTransaction = transaction
            
            // Check if category already exists from CSV
            let existingCategory = transaction["category"] as? String
            
            if existingCategory == nil || existingCategory!.isEmpty {
                // Need to categorize using LFM2
                let description = transaction["description"] as? String ?? ""
                let merchant = transaction["counterparty"] as? String ?? description
                
                print("🏷️ Categorizing transaction \(index + 1)/\(allParsedData.count): \(merchant)")
                
                if !merchant.isEmpty {
                    let category = try await lfm2Service.categorizeTransaction(merchant)
                    mutableTransaction["category"] = category
                    print("   → Category: \(category)")
                } else {
                    mutableTransaction["category"] = "Other"
                    print("   → Category: Other (no merchant/description found)")
                }
            } else {
                print("✅ Transaction \(index + 1) already has category from CSV: \(existingCategory!)")
            }
            
            categorizedData.append(mutableTransaction)
            processingProgress = 0.3 + (0.3 * Double(index + 1) / Double(allParsedData.count))
        }
        
        print("✅ Categorized: \(categorizedData.count) transactions")
        
        // Step 3: Remove duplicates using simple hash-based approach
        processingStep = .deduplicating
        processingMessage = "Removing duplicates..."
        processingProgress = 0.7
        
        let uniqueData = removeDuplicates(from: categorizedData)
        print("✅ After deduplication: \(uniqueData.count) unique transactions")
        processingProgress = 0.8
        
        // Step 4: Create Transaction objects and save
        processingStep = .saving
        processingMessage = "Saving to database..."
        processingProgress = 0.9
        
        let transactions = createTransactionObjects(from: uniqueData)
        print("💾 Created \(transactions.count) Transaction objects, saving to DataManager...")
        try await dataManager.saveTransactions(transactions)
        print("✅ DataManager save completed")
        
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
    
    // Structure to hold column mappings
    struct ColumnMapping {
        var dateColumn: Int?
        var amountColumn: Int?
        var debitColumn: Int?
        var creditColumn: Int?
        var merchantColumn: Int?
        var categoryColumn: Int?
    }
    
    // New LFM2-powered CSV parsing
    private func parseCSVWithLFM2(_ content: String) async throws -> [[String: Any]] {
        var results: [[String: Any]] = []
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard lines.count > 1 else { 
            print("⚠️ CSV has no data rows")
            return results 
        }
        
        // Extract headers (handle quoted values)
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine)
        
        print("📝 Found \(headers.count) columns: \(headers)")
        
        // Use LFM2 to intelligently map columns
        let mapping = try await mapColumnsWithLFM2(headers: headers, sampleRow: lines.count > 1 ? lines[1] : "")
        
        // Parse each row using the mapping
        for i in 1..<lines.count {
            // Handle CSV with quoted values properly
            let values = parseCSVLine(lines[i])
            print("🔍 Row \(i) values: \(values)")
            
            guard values.count == headers.count else { 
                print("⚠️ Row \(i) has \(values.count) values but expected \(headers.count), skipping")
                continue 
            }
            
            var transaction: [String: Any] = [:]
            
            // Extract date
            if let dateCol = mapping.dateColumn, dateCol < values.count {
                transaction["date"] = parseDate(values[dateCol])
            }
            
            // Extract amount (handle debit/credit or single amount)
            var amount: Double = 0
            var hasAmount = false
            
            if let amountCol = mapping.amountColumn, amountCol < values.count {
                // Single amount column found
                amount = parseAmount(values[amountCol])
                hasAmount = true
                print("   💰 Amount from column \(amountCol): \(amount)")
            } else {
                // Try separate debit/credit columns
                if let debitCol = mapping.debitColumn, debitCol < values.count {
                    let debitAmount = parseAmount(values[debitCol])
                    if debitAmount != 0 {
                        amount = -abs(debitAmount) // Debits are ALWAYS negative (expenses)
                        hasAmount = true
                        print("   💳 Debit from column \(debitCol): \(debitAmount) → amount: \(amount)")
                    }
                }
                if let creditCol = mapping.creditColumn, creditCol < values.count {
                    let creditAmount = parseAmount(values[creditCol])
                    if creditAmount != 0 {
                        amount = abs(creditAmount) // Credits are ALWAYS positive (income)
                        hasAmount = true
                        print("   💵 Credit from column \(creditCol): \(creditAmount) → amount: \(amount)")
                    }
                }
            }
            
            if hasAmount {
                transaction["amount"] = amount
            }
            
            // Extract merchant/description
            if let merchantCol = mapping.merchantColumn, merchantCol < values.count {
                transaction["description"] = values[merchantCol]
                transaction["counterparty"] = values[merchantCol]
            }
            
            // Extract category if available (explicitly handle null case)
            if let categoryCol = mapping.categoryColumn, categoryCol < values.count {
                let category = values[categoryCol].trimmingCharacters(in: .whitespaces)
                if !category.isEmpty {
                    transaction["category"] = category
                    print("   🏷️ Category from CSV column \(categoryCol): \(category)")
                } else {
                    // Empty category cell - will be assigned later by LFM2
                    print("   ⚠️ Empty category in column \(categoryCol) - will categorize with LFM2")
                }
            } else {
                // No category column identified - will be assigned later by LFM2
                print("   ℹ️ No category column found - will categorize with LFM2")
            }
            
            // Only add if we have essential fields (date and amount)
            if transaction["date"] != nil && transaction["amount"] != nil {
                // Don't set a default category - let it be nil if not present
                results.append(transaction)
                print("✅ Parsed row \(i): date=\(transaction["date"] ?? "nil"), amount=\(transaction["amount"] ?? "nil"), merchant=\(transaction["description"] ?? "nil"), category=\(transaction["category"] ?? "[to be assigned]")")
            } else {
                print("⚠️ Skipping row \(i): missing essential fields (date=\(transaction["date"] ?? "nil"), amount=\(transaction["amount"] ?? "nil"))")
            }
        }
        
        print("📝 Successfully parsed \(results.count) transactions from CSV")
        return results
    }
    
    private func mapColumnsWithLFM2(headers: [String], sampleRow: String) async throws -> ColumnMapping {
        let headerList = headers.enumerated().map { "Column \($0.offset): '\($0.element)'" }.joined(separator: "\n")
        
        let prompt = """
        Analyze these CSV column headers and identify which columns contain:
        1. Transaction date
        2. Transaction amount (or separate debit/credit)
        3. Merchant/vendor/payee name or description
        4. Category (if available)
        
        Headers:
        \(headerList)
        
        Sample data row: \(sampleRow)
        
        IMPORTANT RULES:
        - Only match columns if you're confident they contain the requested data
        - Return null for any field you cannot confidently identify
        - Do NOT force a match if unsure - it's better to return null
        - For amount: look for "amount", "total", "value" OR separate "debit"/"credit" columns
        - For merchant: look for "merchant", "vendor", "payee", "description", "details"
        - For category: only match if there's an explicit "category" or "type" column
        
        Return ONLY a JSON object with column indices (0-based):
        {"date": X, "amount": X, "debit": X, "credit": X, "merchant": X, "category": X}
        Use null for columns that don't exist or you're unsure about.
        """
        
        print("🤖 Using LFM2 to map CSV columns...")
        let response = try await lfm2Service.inference(prompt, type: "ColumnMapper")
        print("🤖 LFM2 column mapping response: \(response)")
        
        // Parse the response to extract column indices
        var mapping = ColumnMapping()
        
        // Try to extract JSON from response - look for the actual JSON object
        // LFM2 might wrap it in text, so find the JSON part
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards) {
            let jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
            print("🔍 Extracted JSON string: \(jsonString)")
            
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                mapping.dateColumn = json["date"] as? Int
                mapping.amountColumn = json["amount"] as? Int
                mapping.debitColumn = json["debit"] as? Int
                mapping.creditColumn = json["credit"] as? Int
                mapping.merchantColumn = json["merchant"] as? Int
                mapping.categoryColumn = json["category"] as? Int
                
                print("✅ Column mapping from LFM2: date=\(mapping.dateColumn ?? -1), amount=\(mapping.amountColumn ?? -1), debit=\(mapping.debitColumn ?? -1), credit=\(mapping.creditColumn ?? -1), merchant=\(mapping.merchantColumn ?? -1), category=\(mapping.categoryColumn ?? -1)")
            } else {
                print("⚠️ Failed to parse JSON from: \(jsonString)")
            }
        } else {
            print("⚠️ No JSON object found in LFM2 response")
        }
        
        // Fallback: try basic heuristic mapping if LFM2 fails
        if mapping.dateColumn == nil && mapping.merchantColumn == nil {
            print("⚠️ LFM2 mapping failed, using heuristic mapping...")
            mapping = heuristicMapping(headers: headers)
        }
        
        return mapping
    }
    
    private func heuristicMapping(headers: [String]) -> ColumnMapping {
        var mapping = ColumnMapping()
        
        for (index, header) in headers.enumerated() {
            let lower = header.lowercased()
            
            if lower.contains("date") && mapping.dateColumn == nil {
                mapping.dateColumn = index
            } else if lower.contains("amount") && mapping.amountColumn == nil {
                mapping.amountColumn = index
            } else if lower.contains("debit") && mapping.debitColumn == nil {
                mapping.debitColumn = index
            } else if lower.contains("credit") && mapping.creditColumn == nil {
                mapping.creditColumn = index
            } else if (lower.contains("merchant") || lower.contains("description") || 
                      lower.contains("details") || lower.contains("payee")) && mapping.merchantColumn == nil {
                mapping.merchantColumn = index
            } else if lower.contains("category") && mapping.categoryColumn == nil {
                mapping.categoryColumn = index
            }
        }
        
        print("📊 Heuristic mapping: date=\(mapping.dateColumn ?? -1), amount=\(mapping.amountColumn ?? -1), debit=\(mapping.debitColumn ?? -1), credit=\(mapping.creditColumn ?? -1), merchant=\(mapping.merchantColumn ?? -1)")
        
        return mapping
    }
    
    private func parseDate(_ value: String) -> String {
        let dateFormatters = [
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy-MM-dd",
            "MM-dd-yyyy",
            "M/d/yyyy",
            "d/M/yyyy"
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
        
        // If no format matches, use current date as fallback
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd"
        return outputFormatter.string(from: Date())
    }
    
    private func parseAmount(_ value: String) -> Double {
        // Remove quotes if present
        var cleanValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        // Remove currency symbols and whitespace
        cleanValue = cleanValue
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let amount = Double(cleanValue) ?? 0.0
        print("💲 Parsing amount '\(value)' → '\(cleanValue)' → \(amount)")
        return amount
    }
    
    // Parse CSV line handling quoted values
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
        
        // Add the last field
        result.append(current.trimmingCharacters(in: .whitespaces))
        
        return result
    }
    
    
    private func removeDuplicates(from transactions: [[String: Any]]) -> [[String: Any]] {
        var seen = Set<String>()
        var unique: [[String: Any]] = []
        
        for transaction in transactions {
            // Create a unique key based on date, amount, and description
            let date = transaction["date"] as? String ?? ""
            let amount = transaction["amount"] as? Double ?? 0
            let description = transaction["description"] as? String ?? ""
            
            let key = "\(date)|\(amount)|\(description)"
            
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(transaction)
            }
        }
        
        return unique
    }
    
    private func createTransactionObjects(from data: [[String: Any]]) -> [Transaction] {
        print("🔄 Creating Transaction objects from \(data.count) data entries...")
        return data.compactMap { dict in
            guard let dateString = dict["date"] as? String,
                  let amount = dict["amount"] as? Double else {
                print("⚠️ Skipping invalid transaction: date=\(dict["date"] ?? "nil"), amount=\(dict["amount"] ?? "nil")")
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