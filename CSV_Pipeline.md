 Phase 1: CSV Import & File Management

  1. File Selection (TransactionsView.swift:55-59)
    - User clicks + button → Document picker opens
    - Only .csv files allowed
    - Files accessed with security-scoped URLs
  2. File Validation (CSVProcessor.swift:59-73)
    - Security-scoped resource access obtained
    - File contents validated as readable UTF-8
    - File metadata stored in ImportedFile struct
    - Multiple files can be queued for batch processing

  Phase 2: LFM2 Model Initialization

  1. Model Loading (LEAPSDKManager.swift:24-182)
    - 350M parameter LFM2 model loaded from bundle
    - Model copied to writable Library directory for caching
    - LEAP SDK initialized with model runner
    - Conversation context established

  Phase 3: Transaction Processing Pipeline

  1. CSV Parsing (CSVProcessor.swift:125-136, LFM2Service.swift:195-213)
    - Each CSV file processed row-by-row
    - LFM2 inference using TransactionParser.prompt template
    - Extracts: merchant, amount, date, initial category
    - Returns JSON array of parsed transactions
  2. Transaction Categorization (CSVProcessor.swift:141-162,
  LFM2Service.swift:230-249)
    - Each transaction's merchant/description analyzed
    - LFM2 categorizes into: Housing, Food, Transportation, Healthcare,
  Entertainment, Shopping, Savings, Utilities, Income, Other
    - Context from recent transactions used for better accuracy
    - Progress tracked and displayed in UI
  3. Deduplication (CSVProcessor.swift:164-172, LFM2Service.swift:215-228)
    - All transactions across files analyzed for duplicates
    - LFM2 identifies duplicates based on date, amount, merchant similarity
    - Returns unique transaction set
  4. Data Persistence (CSVProcessor.swift:174-180, DataManager.swift:66-91)
    - Transaction objects created with UUID, date, amount, description,
  counterparty, category
    - Saved to UserDefaults (not Core Data despite references)
    - Duplicate check performed before persistence
    - Transactions sorted by date (newest first)

  Phase 4: Insights Generation

  1. Spending Analysis (InsightsView.swift:74-106, LFM2Manager.swift:118-172)
    - Triggered manually or automatically after CSV processing
    - Calculates income (positive amounts) and expenses (negative amounts)
    - Groups expenses by category with totals and percentages
    - LFM2 analyzes patterns using InsightsAnalyzer.prompt
  2. Visualization (InsightsView.swift:29-34)
    - Sankey diagram shows cash flow from income → categories
    - Breakdown section displays category percentages
    - Month selector for historical analysis

  Phase 5: Budget Planning

  1. Chat Interface (BudgetView.swift:16-22, LFM2Manager.swift:174-206)
    - Interactive conversation with LFM2
    - Initial greeting prompts user for financial goals
    - User messages processed with spending context
  2. Budget Negotiation (LFM2Service.swift:270-288)
    - Current spending extracted from transaction data
    - Chat history maintained for context
    - LFM2 uses BudgetNegotiator.prompt to generate recommendations
    - Iterative refinement based on user feedback
  3. Budget Finalization (BudgetView.swift:42-47)
    - Final budget saved with category allocations
    - Summary view displays budget breakdown
    - Stored in UserDefaults for persistence

  Key Technical Details

  - Memory Management: Process handles 4GB+ RAM requirement for 350M model
  - Progress Tracking: Multi-stage progress bars with descriptive messages
  - Error Handling: Fallbacks for parsing failures, model timeouts
  - Batch Processing: Concurrent inference for multiple transactions
  - Caching: Model cached in Library directory, transaction results cached
  - Performance: Telemetry logging tracks inference times, memory usage

  Data Flow Summary

  CSV Files → Parse (LFM2) → Categorize (LFM2) → Deduplicate (LFM2) →
  Save to UserDefaults → Analyze Spending (LFM2) → Generate Insights →
  Budget Chat (LFM2) → Final Budget

  All processing happens locally on-device using the bundled LFM2 model, maintaining
   complete privacy with no network dependencies.