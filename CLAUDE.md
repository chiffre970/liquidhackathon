# Claude Development Context

This file provides important context for Claude Code when working on the PFM app project.

## Project Overview
Building a privacy-first iOS personal finance management app for the Liquid AI Hackathon using LFM2 model for local transaction analysis.

## Key Development Commands
- **Build**: `xcodebuild -project PFMApp.xcodeproj -scheme PFMApp -sdk iphoneos`
- **Test**: `xcodebuild test -project PFMApp.xcodeproj -scheme PFMApp -destination 'platform=iOS Simulator,name=iPhone 15'`
- **Dependencies**: Swift Package Manager integration for LEAP SDK

## Architecture Decisions

### Data Flow
1. CSV import → Row-by-row processing → LFM2 categorization → Core Data persistence
2. Profile page → Insights (analyze button) → Budget recommendations
3. All processing happens locally using bundled 700M parameter LFM2 model

### Key Components
- **ProfileView**: CSV import, transaction editing
- **InsightsView**: Analysis trigger, Sankey visualization  
- **BudgetView**: Goal setting, AI recommendations
- **TransactionProcessor**: LFM2 integration for categorization
- **DataManager**: Core Data operations

### UI/UX Requirements
- Green and cream color scheme
- Native iOS design patterns
- Tab navigation (Profile, Insights/Budget toggle)
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
PFMApp/
├── PFMAppApp.swift           # Main app entry
├── Views/
│   ├── ProfileView.swift     # CSV import, editing
│   ├── InsightsView.swift    # Analysis, Sankey
│   └── BudgetView.swift      # Goals, recommendations
├── Models/
│   ├── Transaction.swift     # Core Data model
│   └── Category.swift        # Spending categories
├── Services/
│   ├── CSVProcessor.swift    # File parsing
│   ├── LFM2Manager.swift     # AI processing
│   └── DataManager.swift     # Core Data
├── Resources/
│   ├── categories.txt        # Predefined categories
│   └── SystemPrompts/        # LFM2 prompts
└── Assets.xcassets          # UI assets
```

## Development Priority
1. Basic app structure and navigation ✓
2. CSV import functionality
3. LFM2 integration and processing
4. UI refinement and visualizations
5. Testing and polish

## Privacy Requirements
- No network requests for AI processing
- All data remains on device
- No user tracking or analytics
- Secure local storage only