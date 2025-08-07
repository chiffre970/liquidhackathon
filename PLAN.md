# Development Plan - PFM App

## Phase 1: Foundation (Days 1-2)
### Project Structure
- [ ] Create Xcode project with SwiftUI
- [ ] Set up folder structure (Views, Models, Services, Resources)
- [ ] Configure LEAP SDK via Swift Package Manager
- [ ] Create basic tab navigation structure
- [ ] Implement color theme (green/cream)

### Core Navigation
- [ ] ProfileView (landing page)
- [ ] InsightsView with Budget toggle
- [ ] Tab bar navigation
- [ ] Empty state messages

## Phase 2: Data Layer (Days 3-4)
### CSV Processing
- [ ] File import functionality in ProfileView
- [ ] CSV parsing with flexible column detection
- [ ] Transaction data model creation
- [ ] Row-by-row processing architecture

### Data Storage
- [ ] Core Data model setup
- [ ] Transaction entity with relationships
- [ ] Data persistence layer
- [ ] Transaction merge logic (debit/credit cancellation)

### Manual Editing
- [ ] Transaction list in ProfileView
- [ ] Manual category editing interface
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
- [ ] "Analyse" button implementation (center → top corner)
- [ ] Loading states with progress bars
- [ ] Spending breakdown calculations
- [ ] Category summation and analysis

### Data Visualization
- [ ] Sankey diagram implementation
- [ ] Income flow visualization
- [ ] Spending category breakdowns
- [ ] Interactive chart elements

### Analysis Features
- [ ] Spending pattern detection
- [ ] Monthly/weekly period selection
- [ ] Insights generation with LFM2

## Phase 5: Budget Management (Days 9-10)
### Budget Creation
- [ ] Goal setting interface
- [ ] Period selection (monthly/weekly)
- [ ] Goal validation with LFM2
- [ ] Budget vs actual tracking

### AI Recommendations
- [ ] Budget analysis system prompt
- [ ] Spending optimization suggestions
- [ ] Goal feasibility assessment
- [ ] Personalized recommendations

### Polish & Testing
- [ ] UI refinement and animations
- [ ] Error modal styling (green/cream theme)
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