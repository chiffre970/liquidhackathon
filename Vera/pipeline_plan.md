# CSV to Transaction Pipeline Plan

## Overview
Transform bank CSV exports into categorized transactions using a hybrid approach that combines smart column detection with focused AI categorization.

## Pipeline Architecture

```
CSV File → Column Detection → Data Extraction → Category Mapping → AI Categorization → Database
```

## Step 1: Smart Column Detection
**Goal**: Identify which CSV columns contain transaction data

### Input
- CSV headers array
- Sample data row

### Process
1. **Fast Path**: Try simple pattern matching first
   - Look for common column names (date, amount, debit, credit, description)
   - If standard format detected → use deterministic mapping

2. **AI Path**: Use LFM2 for unusual formats
   ```swift
   Prompt: Show CSV headers + sample row
   Ask: Which columns contain date, merchant, amount/debit/credit, category?
   Return: JSON mapping of field names (not indices)
   ```

### Output
```json
{
  "date": "Transaction Date",
  "merchant": "Details", 
  "amount": null,
  "debit": "Debit",
  "credit": "Credit",
  "category": "Category"  // null if doesn't exist
}
```

### Critical Rules
- Banks use EITHER single "amount" OR separate "debit/credit"
- Category column might not exist (return null)
- Never hallucinate columns

## Step 2: Data Extraction
**Goal**: Parse CSV rows into structured data

### Amount Calculation Logic
```swift
if (amount_column exists) {
    // Use amount directly (preserve +/- sign)
    amount = parseAmount(row[amount_column])
} else {
    // Calculate from debit/credit
    if (debit_value > 0) amount = -abs(debit_value)  // Always negative
    if (credit_value > 0) amount = +abs(credit_value) // Always positive
}
```

### Category Extraction
```swift
if (category_column exists && value not empty) {
    category = row[category_column]
} else {
    category = null  // Mark for AI categorization
}
```

### Validation
- Required: date, amount (non-zero), merchant (non-empty)
- Optional: category

## Step 3: Category Standardization
**Goal**: Map bank categories to app's standard categories

### If CSV Has Categories
1. Extract unique CSV categories
2. Use LFM2 to map to standard categories:
   ```
   Input: ["Food & Drink", "Transport", "Health"]
   Output: {"Food & Drink": "Food & Dining", "Transport": "Transportation", "Health": "Healthcare"}
   ```
3. Apply mapping to all transactions

### Standard Categories
- Food & Dining
- Transportation
- Healthcare
- Entertainment
- Shopping
- Utilities
- Education
- Insurance
- Personal Care
- Gifts & Donations
- Business Services
- Fees & Charges
- Income
- Other

## Step 4: AI Categorization
**Goal**: Categorize transactions without categories

### Process
1. Filter transactions where category == null
2. Clean merchant names (remove "Purchase At", etc.)
3. Batch process for efficiency:
   ```
   Input: List of {merchant, amount} pairs
   Output: Category for each transaction
   ```
4. Apply categories to transactions

### Optimization
- Cache common merchant → category mappings
- Process in batches of 10-20 transactions
- Skip if all transactions have CSV categories

## Step 5: Database Storage
**Goal**: Save processed transactions

### Process
1. Remove duplicates (based on date + amount + merchant)
2. Create Transaction objects
3. Save to Core Data/UserDefaults
4. Update UI

## Error Handling

### Column Detection Failures
- If no date column found → fail with clear error
- If no amount/debit/credit found → fail with clear error
- If no merchant/description found → fail with clear error

### AI Failures
- If category mapping fails → use "Other"
- If batch categorization fails → retry individual transactions
- Always preserve original CSV category if available

## Performance Targets
- CSV parsing: < 100ms for 1000 rows
- Column detection: < 2s (with AI)
- Categorization: < 5s for 100 transactions
- Total pipeline: < 10s for typical monthly statement

## Implementation Priority
1. **Phase 1**: Basic pipeline with simple column detection
2. **Phase 2**: Add AI column detection for flexibility
3. **Phase 3**: Batch categorization optimization
4. **Phase 4**: Merchant name cleaning and caching

## Testing Strategy
1. Test with CSVs from major banks:
   - Chase (amount column)
   - Bank of America (debit/credit columns)
   - Commonwealth Bank (with categories)
   - Wells Fargo (without categories)

2. Edge cases:
   - Empty category columns
   - Mixed positive/negative in amount column
   - Missing merchant descriptions
   - Foreign currency transactions

## Success Metrics
- ✅ 100% accurate amount signs (expense vs income)
- ✅ Zero hallucinated categories
- ✅ 90%+ categorization accuracy
- ✅ Works with any bank CSV format
- ✅ Fast enough for 1000+ transactions