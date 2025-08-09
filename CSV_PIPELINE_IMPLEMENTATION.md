# CSV to Budget Pipeline Implementation Plan

## Overview
Complete implementation plan for the LFM2-powered data pipeline from CSV import to budget creation.

## Pipeline Architecture
```
CSV Import → LFM2 Parse → LFM2 Categorize → LFM2 Deduplicate → Store → Display → LFM2 Analyze → LFM2 Chat → LFM2 Budget
```

## Current State Analysis

### ✅ Already Implemented
- **LFM2 Service Layer**: Full inference capabilities with LEAPSDKManager
- **Prompt Templates**: All 5 prompts exist (TransactionParser, CategoryClassifier, InsightsAnalyzer, BudgetNegotiator, BudgetInsights)
- **Categories File**: `/Vera/Resources/categories.txt` with 15 categories
- **Models**: Transaction, Budget, CashFlowData, ChatMessage
- **Core Data**: DataManager service ready
- **UI Components**: All views built with progress indicators

### ❌ Missing Connections
- CSV parsing not connected to LFM2
- No deduplication logic
- Transactions not saved to Core Data after processing
- Hardcoded budget values in BudgetChatView

## Implementation Steps

### Phase 1: CSV Processing Pipeline (Priority 1)

#### 1.1 Update CSVProcessor.swift
**File**: `/Vera/Vera/Vera/Services/CSVProcessor.swift`

```swift
class CSVProcessor {
    // Add these methods:
    
    func processCSVWithLFM2(csvContent: String) async throws -> [Transaction] {
        // Step 1: Parse CSV with LFM2
        let parsedData = try await parseCSVWithLFM2(csvContent)
        
        // Step 2: Categorize transactions with LFM2
        let categorizedData = try await categorizeTransactionsWithLFM2(parsedData)
        
        // Step 3: Deduplicate with LFM2
        let deduplicatedData = try await deduplicateWithLFM2(categorizedData)
        
        // Step 4: Create Transaction objects
        let transactions = createTransactionObjects(from: deduplicatedData)
        
        // Step 5: Save to Core Data
        try await saveTransactions(transactions)
        
        return transactions
    }
}
```

**Implementation Details**:
- Add progress tracking for each step
- Update `@Published var processingProgress: Double`
- Show which LFM2 step is running
- Handle errors gracefully

#### 1.2 Create Deduplication Prompt
**File**: Create `/Vera/Vera/Vera/Prompts/TransactionDeduplicator.prompt`

```
You are a transaction deduplication expert. Given a list of transactions, identify and remove duplicates.

Transactions:
{transactions_json}

Rules for identifying duplicates:
1. Same date, amount, and merchant within 24 hours
2. Reversed transactions (refunds)
3. Multiple charges from same merchant on same day (keep only unique ones)

Return a JSON array of unique transactions with a "duplicate_of" field for removed items.
```

#### 1.3 Update PromptManager.swift
Add the new deduplication prompt to the enum:
```swift
enum PromptType: String, CaseIterable {
    // ... existing cases
    case transactionDeduplicator = "TransactionDeduplicator"
}
```

### Phase 2: LFM2 Integration Methods

#### 2.1 Add Processing Methods to LFM2Service.swift
**File**: `/Vera/Vera/Vera/Services/LFM2Service.swift`

```swift
extension LFM2Service {
    func parseCSV(_ csvContent: String) async throws -> [[String: Any]] {
        let prompt = promptManager.fillTemplate(
            type: .transactionParser,
            variables: [
                "csv_content": csvContent,
                "categories": loadCategories()
            ]
        )
        
        let result = try await inference(prompt, type: "CSVParser")
        return parseJSONResponse(result)
    }
    
    func deduplicateTransactions(_ transactions: [[String: Any]]) async throws -> [[String: Any]] {
        let prompt = promptManager.fillTemplate(
            type: .transactionDeduplicator,
            variables: ["transactions_json": transactions]
        )
        
        let result = try await inference(prompt, type: "Deduplicator")
        return parseJSONResponse(result)
    }
}
```

#### 2.2 Load Categories Helper
```swift
private func loadCategories() -> String {
    guard let url = Bundle.main.url(forResource: "categories", withExtension: "txt"),
          let categories = try? String(contentsOf: url) else {
        return ""
    }
    return categories
}
```

### Phase 3: Core Data Integration

#### 3.1 Update DataManager.swift
**File**: `/Vera/Vera/Vera/Services/DataManager.swift`

```swift
extension DataManager {
    func saveTransactions(_ transactions: [Transaction]) async throws {
        let context = persistentContainer.viewContext
        
        for transaction in transactions {
            // Check if transaction already exists
            let fetchRequest = NSFetchRequest<TransactionEntity>(entityName: "TransactionEntity")
            fetchRequest.predicate = NSPredicate(
                format: "date == %@ AND amount == %f AND description == %@",
                transaction.date as NSDate,
                transaction.amount,
                transaction.description
            )
            
            let existing = try context.fetch(fetchRequest).first
            
            if existing == nil {
                // Create new entity
                let entity = TransactionEntity(context: context)
                entity.id = transaction.id
                entity.date = transaction.date
                entity.description = transaction.description
                entity.amount = transaction.amount
                entity.category = transaction.category
                entity.counterparty = transaction.counterparty
            }
        }
        
        try context.save()
    }
}
```

### Phase 4: UI Updates

#### 4.1 Update TransactionsView.swift
Connect the CSV import to the new pipeline:

```swift
.sheet(isPresented: $showingFilePicker) {
    DocumentPicker { url in
        Task {
            await csvProcessor.importAndProcess(from: url)
            loadTransactions()
        }
    }
}
```

#### 4.2 Fix BudgetChatView.swift
Replace hardcoded `createBudget()` method:

```swift
private func createBudget() async {
    // Use LFM2 to generate budget from chat context
    let budgetData = try await lfm2Manager.generateBudgetFromChat(messages)
    onFinalize(budgetData)
}
```

### Phase 5: Progress Indicators

#### 5.1 Add Processing State to CSVProcessor
```swift
@Published var processingStep: ProcessingStep = .idle
@Published var processingMessage: String = ""

enum ProcessingStep {
    case idle
    case parsing
    case categorizing
    case deduplicating
    case saving
    case complete
}
```

#### 5.2 Update UI with Progress
Show real-time progress in TransactionsView during import.

## Testing Plan

### Test Data
Use `/Users/rmh/Code/liquidhackathon/sample_transactions.csv`

### Test Steps
1. **Import CSV**: Verify file loads
2. **Parse**: Check LFM2 extracts all transactions
3. **Categorize**: Verify categories match categories.txt
4. **Deduplicate**: Ensure duplicates removed
5. **Save**: Confirm Core Data persistence
6. **Display**: Check TransactionsView shows data
7. **Analyze**: Verify InsightsView generates analysis
8. **Chat**: Test budget negotiation
9. **Budget**: Confirm dynamic budget creation

## Success Criteria
- [ ] CSV import processes through all LFM2 steps
- [ ] Transactions display with correct categories
- [ ] No duplicate transactions in database
- [ ] Insights show real spending analysis
- [ ] Budget chat generates context-aware budgets
- [ ] Progress indicators show during processing
- [ ] Error handling for failed LFM2 calls

## Implementation Order
1. **Day 1**: CSVProcessor + LFM2 parsing (Phase 1 & 2)
2. **Day 2**: Core Data integration (Phase 3)
3. **Day 3**: UI updates + testing (Phase 4 & 5)

## Risk Mitigation
- **LFM2 Timeout**: Add timeout handling, retry logic
- **Large CSVs**: Process in batches of 100 transactions
- **Memory**: Clear processed data after saving
- **Errors**: Show user-friendly error messages

## Files to Modify
1. `/Vera/Vera/Vera/Services/CSVProcessor.swift` - Main pipeline
2. `/Vera/Vera/Vera/Services/LFM2Service.swift` - Add processing methods
3. `/Vera/Vera/Vera/Services/DataManager.swift` - Save transactions
4. `/Vera/Vera/Vera/Services/PromptManager.swift` - Add deduplicator
5. `/Vera/Vera/Vera/Prompts/TransactionDeduplicator.prompt` - New file
6. `/Vera/Vera/Vera/Views/Transactions/TransactionsView.swift` - Connect pipeline
7. `/Vera/Vera/Vera/Views/Budget/BudgetChatView.swift` - Fix hardcoded budget

## Next Steps
1. Start with CSVProcessor.swift modifications
2. Test with sample_transactions.csv
3. Iterate based on LFM2 response quality