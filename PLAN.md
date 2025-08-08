# Development Plan - PFM App

## Phase 1: Foundation (Days 1-2)
### Project Structure
- [ ] Create Xcode project with SwiftUI
- [ ] Set up folder structure (Views, Models, Services, Components, DesignSystem)
- [ ] Configure LEAP SDK via Swift Package Manager
- [ ] Create design system with colors (#FFFDFD, #E3E3E3, #2E4D40, #71CCA5)
- [ ] Implement Inter font family

### Core Navigation
- [ ] ContentView with custom VBottomNav
- [ ] TransactionsView (main page)
- [ ] InsightsView with Sankey diagram
- [ ] BudgetView with chat interface
- [ ] Reusable components (VContainer, VButton, VCard)

## Phase 2: Data Layer (Days 3-4)
### CSV Processing
- [ ] File import functionality in TransactionsView
- [ ] UploadsSection component for file management
- [ ] CSV parsing with flexible column detection
- [ ] Transaction data model creation
- [ ] Row-by-row processing architecture

### Data Storage
- [ ] Core Data model setup
- [ ] Transaction entity with relationships
- [ ] CashFlowData model for insights
- [ ] Budget and ChatMessage models
- [ ] Data persistence layer

### Transaction Management
- [ ] TransactionsList component
- [ ] TransactionRow display
- [ ] File deletion functionality
- [ ] Data validation and error handling

## Phase 3: AI Integration (Days 5-6)
### LFM2 Setup
- [ ] LEAP SDK integration
- [ ] Bundle 700M model with app
- [ ] Model loading and initialization
- [ ] Memory management for mobile constraints

### Transaction Processing
- [ ] System prompts creation (categorization, insights, budget)
- [ ] LFM2 transaction categorization
- [ ] Progress tracking for batch processing
- [ ] Error handling for AI failures

### Categories System
- [ ] Create categories.txt with predefined options
- [ ] Category assignment logic
- [ ] Category persistence and management

## Phase 4: Insights & Visualization (Days 7-8)
### Insights Page
- [ ] MonthSelector component
- [ ] Automatic analysis on page load
- [ ] Loading states with progress bars
- [ ] BreakdownSection with AI analysis

### Data Visualization
- [ ] SankeyDiagram component implementation
- [ ] Dynamic flow paths based on spending
- [ ] Category percentage calculations
- [ ] Canvas-based rendering

### Analysis Features
- [ ] LFM2 spending pattern detection
- [ ] Monthly period selection
- [ ] Dynamic category generation
- [ ] Natural language insights

## Phase 5: Budget Management (Days 9-10)
### Budget Chat Interface
- [ ] BudgetChatView component
- [ ] ChatBubble message display
- [ ] Input field with send button
- [ ] Chat conversation state management

### Budget Negotiation
- [ ] LFM2 budget conversation handling
- [ ] Context-aware responses
- [ ] Budget finalization logic
- [ ] Mode switching (chat/summary)

### Budget Summary
- [ ] BudgetSummaryView component
- [ ] BudgetVisualization (similar to Sankey)
- [ ] ChangesSection for spending adjustments
- [ ] TargetCard for monthly goals

### Polish & Testing
- [ ] UI refinement and animations
- [ ] Container styling consistency
- [ ] Edge case testing
- [ ] Performance optimization
- [ ] Final testing on device

## Technical Requirements Checklist
- [ ] iOS 15.0+ compatibility
- [ ] Memory efficient processing (4GB+ RAM)
- [ ] Local-only data processing
- [ ] No network dependencies
- [ ] App Store submission readiness

## Key Milestones
1. **Day 2**: Basic navigation and UI structure complete
2. **Day 4**: CSV import and Core Data persistence working
3. **Day 6**: LFM2 categorization functional
4. **Day 8**: Insights visualization complete
5. **Day 10**: Full app with budget features ready for submission

## Risk Mitigation
- **LFM2 Integration**: Research and prototype early (Day 1-2)
- **Performance Issues**: Test on actual device, not simulator
- **Complex Visualizations**: Keep Sankey diagram simple, focus on functionality
- **Time Constraints**: Prioritize core features over polish

## Success Metrics
- [ ] CSV import works with various formats
- [ ] LFM2 categorization accuracy >80%
- [ ] App runs smoothly on iPhone with 4GB+ RAM
- [ ] All core user flows functional
- [ ] Hackathon submission requirements met