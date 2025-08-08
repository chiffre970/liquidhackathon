# Vera App Layout Restructure - Implementation Plan

## Design System

### Typography
- **Main Font**: Inter (all weights)
- **Headings**: Inter Bold/Semibold
- **Body**: Inter Regular
- **Captions**: Inter Light

### Color Palette
```swift
extension Color {
    static let veraWhite = Color(hex: "#FFFDFD")
    static let veraGrey = Color(hex: "#E3E3E3")
    static let veraDarkGreen = Color(hex: "#2E4D40")
    static let veraLightGreen = Color(hex: "#71CCA5")
}
```

### Icons
Location: `/Vera/Vera/Assets.xcassets/Icons/`
- `transaction.svg` - Tab bar icon for Transactions page
- `insights.svg` - Tab bar icon for Insights page  
- `budget.svg` - Tab bar icon for Budget page
- `add.svg` - Plus button for adding CSV files
- `delete.svg` - Delete/trash icon for removing files
- `send.svg` - Send button in chat interface
- `pen.svg` - Edit icon for transaction editing

## Unified Component Architecture

### Reusable Components

#### 1. `VContainer.swift`
```swift
struct VContainer<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    
    var body: some View {
        content
            .padding(padding)
            .background(Color.veraGrey)
            .cornerRadius(20)
            .padding(.horizontal, 16)
    }
}
```

#### 2. `VButton.swift`
```swift
enum VButtonStyle {
    case primary   // Dark green background, white text
    case secondary // Light green background, dark text
    case ghost     // No background, green text
}

struct VButton: View {
    let title: String
    let style: VButtonStyle
    let action: () -> Void
}
```

#### 3. `VDataTable.swift`
```swift
struct VDataTable: View {
    struct Column {
        let title: String
        let key: String
        let width: CGFloat?
    }
    
    let columns: [Column]
    let data: [[String: Any]]
    var showDividers: Bool = true
}
```

#### 4. `VCard.swift`
```swift
struct VCard: View {
    let title: String?
    let subtitle: String?
    let content: AnyView
    var showBorder: Bool = false
}
```

#### 5. `VBottomNav.swift`
```swift
struct VBottomNav: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, label: String)]
    
    // Sliding indicator animation
    // Green background for selected tab
}
```

## Implementation Steps - Detailed

### Phase 1: Navigation Structure & Foundation

#### 1.1 Create Design System
```swift
// Create DesignSystem.swift
struct DesignSystem {
    static let cornerRadius: CGFloat = 20
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12
    static let tabBarHeight: CGFloat = 80
}
```

#### 1.2 Update ContentView
```swift
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color.veraWhite.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main content with container
                Group {
                    switch selectedTab {
                    case 0: TransactionsView()
                    case 1: InsightsView()
                    case 2: BudgetView()
                    default: TransactionsView()
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Custom bottom navigation
                VBottomNav(selectedTab: $selectedTab, tabs: [
                    (icon: "transaction", label: "Transactions"),
                    (icon: "insights", label: "Insights"),
                    (icon: "budget", label: "Budget")
                ])
            }
        }
    }
}
```

### Phase 2: Transactions Page - Detailed

#### 2.1 TransactionsView Structure
```swift
struct TransactionsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingFilePicker = false
    @State private var transactions: [Transaction] = []
    
    var body: some View {
        VContainer {
            VStack(alignment: .leading, spacing: 20) {
                // Header with title and add button
                HStack {
                    Text("Transactions")
                        .font(.custom("Inter-Bold", size: 28))
                        .foregroundColor(.veraDarkGreen)
                    
                    Spacer()
                    
                    Button(action: { showingFilePicker = true }) {
                        Image("add")
                            .renderingMode(.template)
                            .foregroundColor(.veraLightGreen)
                    }
                }
                
                // Your uploads section
                UploadsSection()
                
                // Your transactions section
                TransactionsList(transactions: transactions)
            }
        }
    }
}
```

#### 2.2 UploadsSection Component
```swift
struct UploadsSection: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your uploads")
                .font(.custom("Inter-Semibold", size: 16))
                .foregroundColor(.veraDarkGreen.opacity(0.7))
            
            ForEach(csvProcessor.importedFiles) { file in
                HStack {
                    Text(file.name)
                        .font(.custom("Inter-Regular", size: 14))
                    
                    Spacer()
                    
                    Text(file.importDate, style: .date)
                        .font(.custom("Inter-Light", size: 12))
                    
                    Button(action: { /* Delete */ }) {
                        Image("delete")
                            .renderingMode(.template)
                            .foregroundColor(.red.opacity(0.6))
                    }
                }
                .padding(12)
                .background(Color.veraWhite)
                .cornerRadius(8)
            }
        }
    }
}
```

#### 2.3 TransactionsList Component
```swift
struct TransactionsList: View {
    @Binding var transactions: [Transaction]
    @State private var editingTransaction: Transaction?
    @State private var showingEditModal = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your transactions")
                .font(.custom("Inter-Semibold", size: 16))
                .foregroundColor(.veraDarkGreen.opacity(0.7))
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(transactions) { transaction in
                        TransactionRow(
                            transaction: transaction,
                            onEdit: {
                                editingTransaction = transaction
                                showingEditModal = true
                            }
                        )
                    }
                }
            }
            .background(Color.veraWhite)
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingEditModal) {
            if let transaction = editingTransaction {
                TransactionEditModal(
                    transaction: transaction,
                    isPresented: $showingEditModal,
                    onSave: { updated in
                        updateTransaction(updated)
                    }
                )
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            // Date/Description
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(.veraDarkGreen)
                Text(transaction.date, style: .date)
                    .font(.custom("Inter-Light", size: 12))
                    .foregroundColor(.veraDarkGreen.opacity(0.6))
            }
            
            Spacer()
            
            // Category
            Text(transaction.category ?? "Uncategorized")
                .font(.custom("Inter-Regular", size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.veraLightGreen.opacity(0.2))
                .cornerRadius(8)
            
            // Amount
            Text(String(format: "$%.2f", transaction.amount))
                .font(.custom("Inter-Semibold", size: 14))
                .foregroundColor(transaction.amount < 0 ? .red : .green)
                .frame(width: 80, alignment: .trailing)
            
            // Edit button
            Button(action: onEdit) {
                Image("pen")
                    .renderingMode(.template)
                    .foregroundColor(.veraDarkGreen.opacity(0.5))
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.veraGrey.opacity(0.3))
    }
}
```

### Phase 3: Insights Page - Detailed

#### 3.1 InsightsView Structure
```swift
struct InsightsView: View {
    @State private var selectedMonth = Date()
    @State private var cashFlow: CashFlowData?
    @State private var isAnalyzing = false
    
    var body: some View {
        VContainer {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Insights")
                    .font(.custom("Inter-Bold", size: 28))
                    .foregroundColor(.veraDarkGreen)
                
                // Month selector card
                MonthSelector(selectedMonth: $selectedMonth)
                
                // Sankey diagram
                if let cashFlow = cashFlow {
                    SankeyDiagram(data: cashFlow)
                        .frame(height: 300)
                        .background(Color.veraWhite)
                        .cornerRadius(12)
                }
                
                // Breakdown section
                BreakdownSection(cashFlow: cashFlow)
                
                Spacer()
            }
        }
        .onAppear { analyzeTransactions() }
    }
}
```

#### 3.2 SankeyDiagram Component
```swift
struct SankeyDiagram: View {
    let data: CashFlowData
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw income source on left
                let incomeRect = CGRect(x: 20, y: size.height/2 - 40, 
                                       width: 80, height: 80)
                
                // Draw dynamic categories on right based on LFM2 analysis
                let categoryHeight = size.height / CGFloat(data.categories.count)
                
                for (index, category) in data.categories.enumerated() {
                    let yPos = categoryHeight * CGFloat(index)
                    // Draw flowing paths from income to categories
                    // Width of flow based on percentage of income
                    drawFlow(from: incomeRect, 
                           to: CGRect(x: size.width - 100, y: yPos, 
                                    width: 80, height: categoryHeight * 0.8),
                           percentage: category.percentage,
                           color: .veraLightGreen)
                }
            }
        }
    }
}
```

#### 3.3 BreakdownSection Component
```swift
struct BreakdownSection: View {
    let cashFlow: CashFlowData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.custom("Inter-Semibold", size: 20))
                .foregroundColor(.veraDarkGreen)
            
            if let analysis = cashFlow?.analysis {
                Text(analysis)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(.veraDarkGreen.opacity(0.8))
                    .lineSpacing(4)
            } else {
                Text("Analyzing your spending patterns...")
                    .font(.custom("Inter-Light", size: 14))
                    .foregroundColor(.veraGrey)
            }
        }
        .padding()
        .background(Color.veraWhite)
        .cornerRadius(12)
    }
}
```

### Phase 4: Budget Page - Detailed

#### 4.1 BudgetView Structure
```swift
struct BudgetView: View {
    @State private var budgetMode: BudgetMode = .chat
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var finalizedBudget: Budget?
    
    enum BudgetMode {
        case chat
        case summary
    }
    
    var body: some View {
        VContainer {
            switch budgetMode {
            case .chat:
                BudgetChatView(
                    messages: $messages,
                    inputText: $inputText,
                    onFinalize: finalizeBudget
                )
            case .summary:
                BudgetSummaryView(
                    budget: finalizedBudget,
                    onNewBudget: startNewBudget
                )
            }
        }
    }
}
```

#### 4.2 BudgetChatView Component
```swift
struct BudgetChatView: View {
    @Binding var messages: [ChatMessage]
    @Binding var inputText: String
    let onFinalize: (Budget) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            Text("Budget")
                .font(.custom("Inter-Bold", size: 28))
                .foregroundColor(.veraDarkGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 20)
            
            // Messages scroll view
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                }
            }
            
            // Input area
            HStack(spacing: 12) {
                TextField("Help me create a monthly budget...", text: $inputText)
                    .font(.custom("Inter-Regular", size: 14))
                    .padding(12)
                    .background(Color.veraWhite)
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image("send")
                        .renderingMode(.template)
                        .foregroundColor(.veraWhite)
                        .padding(12)
                        .background(Color.veraLightGreen)
                        .clipShape(Circle())
                }
            }
            .padding(.top, 12)
        }
    }
}
```

#### 4.3 BudgetSummaryView Component
```swift
struct BudgetSummaryView: View {
    let budget: Budget?
    let onNewBudget: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with new budget button
            HStack {
                Text("Budget")
                    .font(.custom("Inter-Bold", size: 28))
                    .foregroundColor(.veraDarkGreen)
                
                Spacer()
                
                Button("New Budget", action: onNewBudget)
                    .font(.custom("Inter-Medium", size: 14))
                    .foregroundColor(.veraLightGreen)
            }
            
            // Budget visualization (similar to Sankey)
            if let budget = budget {
                BudgetVisualization(budget: budget)
                    .frame(height: 300)
                
                // Changes from current spending
                ChangesSection(changes: budget.changes)
                
                // Monthly target
                TargetCard(monthlyTarget: budget.monthlyTarget)
            }
            
            Spacer()
        }
    }
}
```

### Phase 5: LFM2 Integration Services

#### 5.1 LFM2Manager.swift
```swift
class LFM2Manager: ObservableObject {
    private let model: LFM2Model
    
    func categorizeTransaction(_ text: String) async -> TransactionCategory {
        // Process with LFM2 to identify category dynamically
        let prompt = """
        Categorize this transaction: \(text)
        Return only the category name.
        """
        return await model.process(prompt)
    }
    
    func analyzeSpending(_ transactions: [Transaction]) async -> CashFlowData {
        // Generate dynamic categories from transaction data
        let prompt = """
        Analyze these transactions and identify spending categories.
        Group them into meaningful categories and calculate percentages.
        """
        return await model.process(prompt)
    }
    
    func negotiateBudget(_ message: String, context: [ChatMessage]) async -> BudgetResponse {
        // Handle budget negotiation conversation
        let prompt = """
        User wants to adjust their budget: \(message)
        Current spending context: \(context)
        Provide helpful budget recommendations.
        """
        return await model.process(prompt)
    }
}
```

## File Structure
```
Vera/
├── VeraApp.swift
├── ContentView.swift
├── DesignSystem/
│   ├── Colors.swift
│   ├── Typography.swift
│   └── DesignSystem.swift
├── Components/
│   ├── VContainer.swift
│   ├── VButton.swift
│   ├── VDataTable.swift
│   ├── VCard.swift
│   └── VBottomNav.swift
├── Views/
│   ├── Transactions/
│   │   ├── TransactionsView.swift
│   │   ├── UploadsSection.swift
│   │   └── TransactionsList.swift
│   ├── Insights/
│   │   ├── InsightsView.swift
│   │   ├── SankeyDiagram.swift
│   │   └── BreakdownSection.swift
│   └── Budget/
│       ├── BudgetView.swift
│       ├── BudgetChatView.swift
│       └── BudgetSummaryView.swift
├── Models/
│   ├── Transaction.swift
│   ├── CashFlowData.swift
│   ├── Budget.swift
│   └── ChatMessage.swift
├── Services/
│   ├── CSVProcessor.swift
│   ├── LFM2Manager.swift
│   └── DataManager.swift
└── Assets.xcassets/
    └── Icons/
        ├── transaction.svg
        ├── insights.svg
        ├── budget.svg
        ├── add.svg
        ├── delete.svg
        └── send.svg
```

## Development Priority
1. Design system and reusable components
2. Navigation structure with custom bottom nav
3. Basic views with placeholder content
4. LFM2 integration for dynamic categorization
5. Interactive features (chat, file upload)
6. Data visualization (Sankey, budget flow)
7. Polish and animations