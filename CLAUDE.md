# Claude Development Context - Vera Thought Organizer

This file provides comprehensive context for Claude Code when working on the Vera thought organization app.

## Project Overview
Building Vera - an elegant iOS app that captures spoken thoughts and intelligently organizes them using LFM2 700M model for on-device AI processing.

**Status**: Starting fresh rebuild - pivoted from finance app to thought organizer
**Hackathon**: Liquid AI Hackathon 2025

## Core Concept
Users tap an ethereal particle orb to record thoughts. The app transcribes speech using Apple's Speech framework, then uses LFM2 to categorize, summarize, and organize thoughts into actionable insights.

## Key Features

### 1. Recording Interface
- Single tap on particle orb to start/stop recording
- Visual feedback: particles shimmer during recording
- Minimalist design - just the orb on main screen

### 2. Processing Pipeline
- **Transcription**: Apple Speech Framework (real-time)
- **Organization**: LFM2 categorizes as Action vs Thought
- **Summarization**: LFM2 creates concise summaries
- **Background Processing**: All happens after recording stops

### 3. Thought Categories
- **Actions**: Tasks to do (e.g., "write essay about X")
  - Trigger reminder notifications
  - Focus on the task itself
- **Thoughts**: Ideas, observations, reflections
  - Trigger insight notifications
  - Focus on the content/insight

### 4. Visual Design
- **Color Palette**: Pink, purple, blue, red ethereal gradients
- **Particle System**: Fluid, natural movement
- **Rhythm Response**: Particles react to voice rhythm/amplitude
- **Minimalist UI**: White background, floating orb center stage

## Technical Architecture

### Models
```swift
Thought {
  id: UUID
  rawTranscription: String
  summary: String
  category: Category (action/thought)
  sessionId: UUID
  timestamp: Date
  tags: [String]
  priority: Priority?
}

Session {
  id: UUID
  startTime: Date
  endTime: Date
  thoughts: [Thought]
  overallSummary: String
}

Category {
  case action(deadline: Date?)
  case thought(theme: String)
}
```

### Services
1. **AudioRecorder**: AVAudioRecorder for capturing
2. **TranscriptionService**: Speech framework integration
3. **LFM2Processor**: Categorization and summarization
4. **NotificationManager**: Smart reminders based on category
5. **StorageManager**: Core Data persistence

### UI Structure
```
ContentView
├── RecordingView
│   ├── ParticleOrbView (tap to record)
│   └── RecordingIndicator
└── LibraryView (future - browse thoughts)
```

## LFM2 Prompts

### Categorization Prompt
```
Analyze this transcribed thought and categorize it:
"{transcription}"

Determine if this is:
1. ACTION - Something the user wants to do
2. THOUGHT - An idea, observation, or reflection

Response format:
{
  "category": "ACTION" or "THOUGHT",
  "summary": "One sentence summary",
  "tags": ["relevant", "tags"],
  "priority": "high/medium/low" (for actions only),
  "deadline_hint": "any mentioned timeframe" (for actions only)
}
```

### Session Summary Prompt
```
Summarize this recording session's thoughts:
{thoughts_json}

Create a brief overview highlighting:
- Key themes
- Important actions identified
- Notable insights

Keep it under 3 sentences.
```

## Implementation Priority

1. **Phase 1 - Core Recording** ✓
   - Basic UI with particle orb
   - Audio recording start/stop
   - Simple visual feedback

2. **Phase 2 - Transcription**
   - Speech framework integration
   - Real-time transcription display
   - Error handling

3. **Phase 3 - AI Processing**
   - LFM2 integration for categorization
   - Background processing queue
   - Summary generation

4. **Phase 4 - Notifications**
   - Action reminders
   - Thought insights
   - Smart scheduling

5. **Phase 5 - Polish**
   - Particle animations
   - Rhythm response
   - UI refinements

## File Structure (Proposed)
```
Vera/
├── VeraApp.swift
├── Core/
│   ├── Models/
│   │   ├── Thought.swift
│   │   ├── Session.swift
│   │   └── Category.swift
│   ├── Services/
│   │   ├── AudioRecorder.swift
│   │   ├── TranscriptionService.swift
│   │   ├── LFM2Processor.swift
│   │   ├── NotificationManager.swift
│   │   └── StorageManager.swift
│   └── Extensions/
├── UI/
│   ├── Recording/
│   │   ├── RecordingView.swift
│   │   ├── ParticleOrbView.swift
│   │   └── RecordingIndicator.swift
│   ├── Library/
│   │   └── LibraryView.swift (future)
│   └── Components/
│       └── GradientBackground.swift
├── Resources/
│   └── LFM2/
│       └── lfm_700m.bundle
└── Info.plist
```

## Permissions Required
- `NSMicrophoneUsageDescription` - "Vera needs microphone access to record your thoughts"
- `NSSpeechRecognitionUsageDescription` - "Vera transcribes your speech locally to organize thoughts"
- `NSUserNotificationsUsageDescription` - "Vera sends reminders about your actions and insights"

## Design References
- Particle effects: Think lava lamp meets aurora borealis
- Colors: Gradient meshes with pink (#FF69B4), purple (#9370DB), blue (#4169E1), red (#DC143C)
- Animation: Smooth, organic, breathing-like movement
- Interaction: Immediate haptic feedback on tap

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

1. **Background Processing**: Use `BGTaskScheduler` for processing after app closes
2. **Memory Management**: Stream audio to disk, process in chunks
3. **Privacy**: All processing local, no network calls
4. **Performance**: Optimize particle rendering with Metal if needed
5. **Testing**: Test on real device for audio/speech features

## Known Constraints
- Speech recognition requires iOS 15+
- Background processing limited to system scheduling
- LFM2 model size (~500MB) affects app bundle
- Particle effects may need optimization for older devices

## Next Steps
1. Clean up all finance-related code ✓
2. Implement basic recording UI with particle orb
3. Integrate Speech framework
4. Connect LFM2 for processing
5. Add notification system
6. Polish animations and interactions