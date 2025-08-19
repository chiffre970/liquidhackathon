# Claude Development Context - Vera Meeting Assistant

This file provides comprehensive context for Claude Code when working on the Vera meeting recording and transcription app.

## Project Overview
Vera is an iOS app that records meetings, transcribes speech in real-time using Apple's Speech framework, and uses the LFM2 700M model for AI-powered meeting analysis and summary generation.

**Status**: Core recording, transcription, and AI analysis features implemented
**Hackathon**: Liquid AI Hackathon 2025

## Core Concept
Users record meetings with a single tap, get real-time transcription, and receive AI-generated summaries. The app uses LFM2 (via Leap SDK) to analyze transcripts and provide structured meeting insights.

## Current Implementation

### ✅ Implemented Features
1. **Recording & Transcription**
   - Audio recording with AVAudioRecorder
   - Real-time speech-to-text using Apple Speech framework
   - Live transcript display during recording
   - Recording duration timer
   - Persistent storage using Core Data

2. **Meeting Management**
   - Create/edit meetings with titles
   - Manual note-taking alongside transcription
   - Meeting templates (1-on-1, Stand-up, Client, Brainstorm)
   - Meeting list view with search
   - Meeting detail view with transcript and notes

3. **AI Analysis (LFM2 Integration)**
   - Leap SDK integration for on-device inference
   - Post-meeting transcript analysis
   - Text-based summary generation
   - Processing status tracking

4. **UI/UX**
   - Tab-based navigation (Meeting, List, Settings)
   - Clean, minimal interface
   - Recording indicator with red dot
   - Template picker sheet

### 🚧 In Progress / Planned
- Export functionality (PDF, Markdown, etc.)
- Action item extraction
- Key decision identification
- Background processing optimization
- Share sheet integration

## Technical Architecture

### Core Data Model
```swift
Meeting {
  id: UUID
  title: String
  date: Date
  duration: TimeInterval
  rawNotes: String?          // User's manual notes
  transcript: String?        // Full audio transcription
  enhancedNotes: String?     // LFM2 processed summary
  templateUsed: String?
  insights: Data?            // JSON MeetingInsights
  processingStatus: String?  // pending/processing/completed/failed
  lastProcessedDate: Date?
}

MeetingInsights {
  executiveSummary: String
  keyPoints: [String]
  criticalInfo: String?
  unresolvedTopics: [String]
  risks: [String]
  followUpItems: [String]
}
```

### Key Services
1. **MeetingRecordingService**: Central service managing recording, transcription, and meetings
2. **TranscriptionService**: Real-time speech recognition using SFSpeechRecognizer
3. **MeetingEnhancementService**: LFM2 integration for AI analysis
4. **LFM2Manager**: Leap SDK wrapper for model inference
5. **PersistenceController**: Core Data stack management

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

## LFM2 Integration

The app uses Leap SDK to run the LFM2-1.2B model on-device:
- Model bundle: `LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle` 
- Inference: Streaming text generation with customizable temperature/top-p
- Current approach: Simple text prompts for meeting analysis (JSON parsing available but not currently used)
- Processing: Happens after recording ends via `analyzeCompletedMeeting()`


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

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.