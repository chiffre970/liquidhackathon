# Claude Development Context - Vera Meeting Assistant

This file provides comprehensive context for Claude Code when working on the Vera meeting recording and transcription app.

## Project Overview
Building Vera - an elegant iOS app that records meetings, transcribes speech in real-time, and uses the LFM2 700M model for intelligent note enhancement and meeting insights extraction.

**Status**: Building meeting recording and transcription features
**Hackathon**: Liquid AI Hackathon 2025

## Core Concept
Users can effortlessly record meetings with a single tap. The app transcribes speech in real-time using Apple's Speech framework, then uses LFM2 to extract action items, key decisions, and generate enhanced meeting summaries with actionable insights.

## Key Features

### 1. Recording Interface
- Minimal recording controls - start/stop with one tap
- Real-time duration counter
- Visual recording indicator (subtle red dot)
- Pause/resume capability for interruptions
- Background recording support

### 2. Processing Pipeline
- **Transcription**: Apple Speech Framework (real-time, on-device)
- **Note Enhancement**: LFM2 creates structured summaries
- **Action Extraction**: LFM2 identifies tasks and owners
- **Insights Generation**: LFM2 extracts key decisions and questions
- **Background Processing**: All AI enhancement happens after recording

### 3. Meeting Organization
- **Action Items**: Extracted tasks with owners and deadlines
  - Automatic reminders for upcoming deadlines
  - Mark as complete functionality
- **Key Decisions**: Important choices made during meeting
  - Contextual information preserved
  - Timestamp references
- **Questions**: Unresolved items needing follow-up
  - Flag for follow-up needed
  - Link to relevant context

### 4. Visual Design
- **Clean Interface**: White background, minimal chrome
- **Typography Focus**: Clear, readable text hierarchy
- **Recording Indicator**: Subtle red dot with timer
- **Tab Navigation**: Simple bottom tabs for core functions
- **Professional Aesthetic**: Business-appropriate design

## Technical Architecture

### Models
```swift
Meeting {
  id: UUID
  title: String
  date: Date
  duration: TimeInterval
  rawNotes: String?          // User's manual notes
  transcript: String?        // Full audio transcription
  enhancedNotes: String?     // LFM2 processed summary
  actionItems: Data?         // JSON array of ActionItem
  keyDecisions: Data?        // JSON array of KeyDecision
  questions: Data?           // JSON array of Question
  templateUsed: String?
  audioFileURL: String?
}

ActionItem {
  id: UUID
  task: String
  owner: String?
  deadline: Date?
  isCompleted: Bool
}

KeyDecision {
  id: UUID
  decision: String
  context: String?
  timestamp: Date
}

Question {
  id: UUID
  question: String
  context: String?
  needsFollowUp: Bool
}
```

### Services
1. **MeetingRecordingService**: Manages recording lifecycle
2. **AudioRecorder**: AVAudioRecorder for capturing
3. **TranscriptionService**: Speech framework integration
4. **MeetingEnhancementService**: LFM2 processing pipeline
5. **ActionItemExtractor**: Identifies tasks from transcript
6. **InsightsGenerator**: Extracts decisions and questions
7. **ExportService**: Multiple format export options
8. **StorageManager**: Core Data persistence

### UI Structure
```
ContentView (TabView)
├── MeetingView (Recording)
│   ├── NoteEditorView
│   └── RecordingIndicatorView
├── MeetingListView (History)
│   ├── MeetingRowView
│   └── MeetingSearchBar
└── SettingsView (Preferences)
```

## LFM2 Prompts

### Meeting Enhancement Prompt
```
Analyze this meeting and provide structured insights:

Transcript: "{transcript}"
User Notes: "{userNotes}"

Generate:
1. Executive Summary (2-3 sentences capturing the essence)
2. Key Points (maximum 5 bullet points)
3. Decisions Made (with context)
4. Next Steps (actionable items)

Format as structured JSON for parsing.
```

### Action Item Extraction Prompt
```
Extract all action items from this meeting transcript:
"{transcript}"

For each action item identify:
- Task description (clear and actionable)
- Owner (person responsible if mentioned)
- Deadline (if any timeframe mentioned)
- Priority (high/medium/low based on context)

Return as JSON array with structured objects.
```

### Insights Generation Prompt
```
Analyze this meeting for important insights:
"{transcript}"

Extract:
1. Key Questions Raised (that need answers)
2. Important Decisions (with rationale)
3. Risks or Concerns Mentioned
4. Follow-up Items Required

Focus on actionable intelligence, not just summary.
```

## Implementation Priority

1. **Phase 1 - Core Recording** ✓
   - Basic recording UI
   - Audio capture and storage
   - Duration tracking

2. **Phase 2 - Real-time Transcription** (Current)
   - Speech framework integration
   - Live transcript display
   - Error handling for speech recognition

3. **Phase 3 - Meeting Management**
   - Meeting list view
   - Search functionality
   - Basic CRUD operations

4. **Phase 4 - AI Enhancement**
   - LFM2 integration
   - Action item extraction
   - Summary generation
   - Insights processing

5. **Phase 5 - Export & Share**
   - Multiple export formats
   - Share sheet integration
   - Template system

## File Structure
```
Vera/
├── VeraApp.swift
├── Core/
│   ├── Models/
│   │   └── Meeting.swift
│   ├── Services/
│   │   ├── MeetingRecordingService.swift
│   │   ├── AudioRecorder.swift
│   │   ├── TranscriptionService.swift
│   │   ├── MeetingEnhancementService.swift
│   │   ├── ActionItemExtractor.swift
│   │   ├── InsightsGenerator.swift
│   │   ├── ExportService.swift
│   │   └── StorageManager.swift
│   └── Extensions/
├── Views/
│   ├── Meeting/
│   │   ├── MeetingView.swift
│   │   ├── NoteEditorView.swift
│   │   └── RecordingIndicatorView.swift
│   ├── MeetingList/
│   │   ├── MeetingListView.swift
│   │   ├── MeetingRowView.swift
│   │   └── MeetingSearchBar.swift
│   ├── MeetingDetail/
│   │   ├── MeetingDetailView.swift
│   │   ├── EnhancedNotesView.swift
│   │   ├── ActionItemsView.swift
│   │   └── TranscriptView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/
├── Resources/
│   ├── LFM2/
│   │   └── lfm_700m.bundle
│   └── Templates/
│       └── DefaultTemplates.json
└── Vera.xcdatamodeld
```

## Meeting Templates
```swift
templates = [
  "1-on-1": "Agenda • Discussion Points • Action Items • Next Meeting",
  "Stand-up": "Yesterday • Today • Blockers",
  "Client Meeting": "Agenda • Notes • Decisions • Follow-up",
  "Brainstorm": "Ideas • Pros/Cons • Next Steps",
  "Review": "What Went Well • What Could Improve • Action Items"
]
```

## Permissions Required
- `NSMicrophoneUsageDescription` - "Vera needs microphone access to record meetings"
- `NSSpeechRecognitionUsageDescription` - "Vera transcribes speech locally to create meeting notes"
- `NSUserNotificationsUsageDescription` - "Vera sends reminders for action items from your meetings"

## Export Formats
- **Markdown**: Structured with headers and lists
- **Plain Text**: Simple formatted text
- **PDF**: Professional meeting minutes format
- **JSON**: Structured data for integration
- **Share Sheet**: Direct sharing to other apps
- **Email**: Pre-formatted email with summary

## Development Commands
```bash
# Build
xcodebuild -project Vera.xcodeproj -scheme Vera -sdk iphoneos

# Test on simulator
xcodebuild test -project Vera.xcodeproj -scheme Vera -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean build
xcodebuild clean -project Vera.xcodeproj -scheme Vera
```

## Critical Implementation Notes

1. **Audio Management**: Chunk recordings every 30 seconds for reliability
2. **Background Processing**: Use `BGTaskScheduler` for LFM2 processing
3. **Memory Efficiency**: Stream audio to disk, process in chunks
4. **Privacy First**: All processing on-device, no cloud dependencies
5. **Performance**: Optimize for 60+ minute meetings
6. **Search**: Full-text search across transcripts and notes
7. **Offline First**: Full functionality without network

## Meeting Recording Best Practices
- Auto-save progress every 5 seconds
- Preserve recording on app crash
- Handle interruptions (calls, etc.)
- Support background recording
- Efficient storage compression

## LFM2 Integration Notes
- Model size: ~500MB
- Processing time target: <30 seconds per hour of audio
- Batch processing for efficiency
- Queue management for multiple meetings
- Fallback to basic transcription if LFM2 unavailable

## Success Metrics
- Recording reliability: 99.9% uptime
- Transcription accuracy: >90%
- Action item extraction: >80% accuracy
- Processing time: <30s per meeting hour
- App responsiveness: <100ms UI interactions
- Storage efficiency: <10MB per meeting hour

## Next Steps
1. Complete real-time transcription integration
2. Implement meeting list and search
3. Add LFM2 enhancement pipeline
4. Create export functionality
5. Add template system
6. Polish UI and animations
# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.