# Vera - Meeting Recording & Transcription App

## Overview
Vera is an AI-powered meeting assistant that records, transcribes, and intelligently enhances meeting notes using the LFM2 700M model for on-device processing.

## Current Status
- ✅ Basic recording infrastructure in place
- ✅ Core Data models defined (Meeting entity)
- ✅ MeetingRecordingService implemented
- 🚧 Real-time transcription integration needed
- 🚧 UI implementation in progress
- ⏳ LFM2 enhancement pipeline pending

## Phase 1: Foundation ✅ COMPLETE

### Data Model ✅
- Meeting entity with all required fields
- ActionItem, KeyDecision, Question structs
- Core Data integration

### Recording Service ✅
- MeetingRecordingService with pause/resume
- Audio chunking (30-second intervals)
- Background processing preparation

## Phase 2: Transcription & UI 🚧 IN PROGRESS

### Real-time Transcription
**Priority: HIGH**
- [ ] Complete Speech framework integration
- [ ] Live transcript display during recording
- [ ] Error handling for speech recognition failures
- [ ] Offline transcription support

### Meeting View UI
**Priority: HIGH**
- [ ] Clean recording interface with minimal controls
- [ ] Real-time duration display
- [ ] Note editor with markdown support
- [ ] Recording indicator (red dot + timer)

### Meeting List View
**Priority: HIGH**
- [ ] Chronological meeting list
- [ ] Search functionality
- [ ] Swipe actions (delete, share)
- [ ] Meeting preview (title, date, duration, snippet)

## Phase 3: LFM2 AI Enhancement ⏳ PENDING

### Meeting Enhancement Service
**Priority: MEDIUM**
```swift
Tasks:
- Implement LFM2Manager integration
- Create enhancement prompts
- Process meetings in background
- Generate structured summaries
```

### Action Item Extraction
**Priority: MEDIUM**
```swift
Extract from transcript:
- Task descriptions
- Assigned owners
- Deadlines mentioned
- Priority levels
```

### Insights Generation
**Priority: MEDIUM**
```swift
Identify:
- Key decisions made
- Important questions raised
- Follow-up items needed
- Risks or concerns
```

## Phase 4: Export & Templates ⏳ PENDING

### Export System
**Priority: LOW**
- [ ] Markdown export
- [ ] PDF generation
- [ ] Share sheet integration
- [ ] Email formatted output

### Template System
**Priority: LOW**
- [ ] Pre-built meeting templates
- [ ] Custom template creation
- [ ] Quick template selection

## Implementation Checklist

### Immediate Tasks (This Week)
1. [ ] Fix TranscriptionService real-time updates
2. [ ] Create MeetingView with recording controls
3. [ ] Implement MeetingListView
4. [ ] Add tab navigation structure
5. [ ] Test recording reliability

### Next Sprint
1. [ ] Integrate LFM2 for enhancement
2. [ ] Build action item extraction
3. [ ] Create meeting detail view
4. [ ] Add search functionality
5. [ ] Implement export options

### Polish & Optimization
1. [ ] Memory optimization for long recordings
2. [ ] Background task scheduling
3. [ ] Notification system for reminders
4. [ ] Settings and preferences
5. [ ] Onboarding flow

## Technical Debt
- [ ] Remove old particle animation code
- [ ] Clean up unused thought-related models
- [ ] Optimize audio file storage
- [ ] Implement proper error handling
- [ ] Add unit tests for services

## Known Issues
- TranscriptionService not updating transcript in real-time
- Need to implement audio session handling for interruptions
- Background processing not yet configured
- LFM2 model not integrated

## Architecture Notes

### Service Layer
```
MeetingRecordingService (Orchestrator)
    ├── AudioRecorder (Audio capture)
    ├── TranscriptionService (Speech-to-text)
    └── MeetingEnhancementService (LFM2 processing)
```

### Data Flow
```
Recording → Transcription → Storage → Enhancement → Display
```

### UI Structure
```
TabView
├── Record Tab (MeetingView)
├── Meetings Tab (MeetingListView)
└── Settings Tab (SettingsView)
```

## Performance Targets
- Support 60+ minute recordings
- Real-time transcription with <2s delay
- LFM2 processing <30s per hour
- Search results <1s response
- App size <200MB (excluding model)

## Testing Requirements
- [ ] Long recording sessions (>1 hour)
- [ ] Interruption handling (calls, notifications)
- [ ] Background processing
- [ ] Memory usage monitoring
- [ ] Transcription accuracy

## Deployment Checklist
- [ ] App permissions configured
- [ ] Privacy policy updated
- [ ] App Store description
- [ ] Screenshots prepared
- [ ] TestFlight beta testing

## Resources
- LFM2 Model: `Resources/LFM2/lfm_700m.bundle`
- Templates: `Resources/Templates/DefaultTemplates.json`
- Icons: System SF Symbols

## Meeting Templates (To Implement)
1. **1-on-1**: Agenda, Discussion, Action Items, Next Steps
2. **Stand-up**: Yesterday, Today, Blockers
3. **Client Meeting**: Objectives, Notes, Decisions, Follow-up
4. **Brainstorm**: Ideas, Evaluation, Next Steps
5. **Review**: Achievements, Improvements, Action Items

## Success Criteria
- ✅ Records meetings reliably
- ✅ Transcribes speech accurately
- ⏳ Extracts actionable insights
- ⏳ Exports in multiple formats
- ⏳ Searches across all content
- ⏳ Works completely offline

## Next Action
**Focus on completing the UI implementation and real-time transcription before moving to LFM2 enhancement features.**