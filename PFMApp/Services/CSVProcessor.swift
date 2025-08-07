import Foundation

class CSVProcessor: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    func importCSV(from url: URL) {
        isProcessing = true
        errorMessage = nil
        
        do {
            let content = try String(contentsOf: url)
            let parsedTransactions = try parseCSV(content: content)
            
            DispatchQueue.main.async {
                self.mergeTransactions(parsedTransactions)
                self.isProcessing = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to import CSV: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    private func parseCSV(content: String) throws -> [Transaction] {
        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else { throw CSVError.emptyFile }
        
        let headers = parseCSVLine(lines[0]).map { $0.lowercased() }
        let dataLines = Array(lines.dropFirst()).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let dateIndex = findColumnIndex(headers: headers, candidates: ["date", "transaction date", "posting date"])
        let amountIndex = findColumnIndex(headers: headers, candidates: ["amount", "debit", "credit", "transaction amount"])
        let descriptionIndex = findColumnIndex(headers: headers, candidates: ["description", "memo", "transaction description", "details"])
        
        guard let dateIdx = dateIndex, let amountIdx = amountIndex, let descIdx = descriptionIndex else {
            throw CSVError.missingRequiredColumns
        }
        
        var transactions: [Transaction] = []
        let dateFormatter = createDateFormatter()
        
        for line in dataLines {
            let fields = parseCSVLine(line)
            guard fields.count > max(dateIdx, amountIdx, descIdx) else { continue }
            
            guard let date = dateFormatter.date(from: fields[dateIdx]) else { continue }
            guard let amount = Double(fields[amountIdx].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) else { continue }
            
            let description = fields[descIdx]
            let counterparty = extractCounterparty(from: description)
            
            let transaction = Transaction(
                date: date,
                amount: amount,
                description: description,
                counterparty: counterparty
            )
            transactions.append(transaction)
        }
        
        return transactions
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return fields
    }
    
    private func findColumnIndex(headers: [String], candidates: [String]) -> Int? {
        for candidate in candidates {
            if let index = headers.firstIndex(where: { $0.contains(candidate) }) {
                return index
            }
        }
        return nil
    }
    
    private func createDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }
    
    private func extractCounterparty(from description: String) -> String? {
        let components = description.components(separatedBy: " ")
        return components.count > 1 ? components.dropLast().joined(separator: " ") : nil
    }
    
    private func mergeTransactions(_ newTransactions: [Transaction]) {
        for transaction in newTransactions {
            if !transactions.contains(where: { existing in
                abs(existing.date.timeIntervalSince(transaction.date)) < 86400 &&
                abs(existing.amount - transaction.amount) < 0.01 &&
                existing.description == transaction.description
            }) {
                transactions.append(transaction)
            }
        }
        
        transactions.sort { $0.date > $1.date }
    }
}

enum CSVError: LocalizedError {
    case emptyFile
    case missingRequiredColumns
    
    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The CSV file is empty"
        case .missingRequiredColumns:
            return "Required columns (date, amount, description) not found"
        }
    }
}