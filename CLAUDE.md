# Claude Development Context

This file provides important context for Claude Code when working on the Vera app project.

## Project Overview
Building Vera - a privacy-first iOS personal finance assistant for the Liquid AI Hackathon using LFM2 model for local transaction analysis.

## Key Development Commands
- **Build**: `xcodebuild -project Vera.xcodeproj -scheme Vera -sdk iphoneos`
- **Test**: `xcodebuild test -project Vera.xcodeproj -scheme Vera -destination 'platform=iOS Simulator,name=iPhone 15'`
- **Dependencies**: Swift Package Manager integration for LEAP SDK

## Architecture Decisions

### Data Flow
1. CSV import → Row-by-row processing → LFM2 categorization → Core Data persistence
2. Transactions page → Insights (automatic analysis) → Budget chat/summary
3. All processing happens locally using bundled 700M parameter LFM2 model

### Key Components
- **TransactionsView**: CSV import, file management, transaction list
- **InsightsView**: Sankey visualization, spending breakdown  
- **BudgetView**: Chat interface, budget negotiation, summary view
- **LFM2Manager**: AI processing for categorization and analysis
- **DataManager**: Core Data operations

### UI/UX Requirements
- Color palette: #FFFDFD (white), #E3E3E3 (grey), #2E4D40 (dark green), #71CCA5 (light green)
- Inter font family (all weights)
- Custom bottom navigation with sliding indicator
- Container-based layout with rounded corners (20px radius)
- Loading states with progress bars
- Error modals matching app styling

## Technical Constraints
- iOS 15.0+ target
- Bundle 700M LFM2 model (~500MB)
- Memory efficient processing (4GB+ RAM recommended)
- No network dependencies for core functionality
- Core Data for local persistence

## System Prompts Required
1. **Categorization**: Transaction parsing and category assignment
2. **Insights**: Spending analysis and pattern recognition  
3. **Budget**: Goal validation and recommendation generation

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

## Privacy Requirements
- No network requests for AI processing
- All data remains on device
- No user tracking or analytics
- Secure local storage only