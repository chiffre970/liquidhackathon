# Vera - AI-Powered Meeting Assistant

An intelligent iOS app that records meetings, transcribes conversations in real-time, and uses on-device AI to extract actionable insights.

## Vision

Vera transforms meetings into structured, actionable intelligence. Simply tap to record, and let the app transcribe conversations and extract action items, key decisions, and important questions using the powerful LFM2 1.2B model - all processed locally on your device.

## Features

- **One-Tap Recording**: Start/stop meeting recordings with minimal friction
- **Real-Time Transcription**: Apple's Speech framework converts speech to text as you record
- **Intelligent Enhancement**: LFM2 generates summaries, extracts action items, and identifies key decisions
- **Smart Organization**: Automatically categorizes and tags meeting content
- **Action Tracking**: Extracted tasks with owners, deadlines, and completion status
- **Professional Export**: Share notes as Markdown, PDF, or formatted email
- **Complete Privacy**: All processing happens on-device, no cloud dependencies

## Technical Stack

- **Platform**: iOS 15.0+
- **UI Framework**: SwiftUI
- **AI Model**: LFM2 1.2B (via LEAP SDK)
- **Speech**: Apple Speech Framework
- **Audio**: AVFoundation
- **Storage**: Core Data
- **Notifications**: UserNotifications

## Architecture

```
Vera/
├── Core/
│   ├── Models/         # Meeting, ActionItem, KeyDecision
│   ├── Services/       # Recording, Transcription, AI Enhancement
│   └── Storage/        # Core Data persistence
├── Views/
│   ├── Meeting/        # Recording interface
│   ├── MeetingList/    # Meeting history
│   └── MeetingDetail/  # Enhanced notes view
└── Resources/
    └── LFM2/           # 1.2B model bundle
```

## Privacy First

- No network requests for processing
- All AI inference on-device
- No analytics or tracking
- Secure local storage only
- Audio recordings encrypted at rest

## Development

Built for the Liquid AI Hackathon 2025

### Requirements
- Xcode 15+
- iOS Device (for testing audio recording)
- ~500MB free space for LFM2 model

### Setup
```bash
xcodebuild -project Vera.xcodeproj -scheme Vera -sdk iphoneos
```

## Key Capabilities

### Meeting Recording
- Continuous audio capture with pause/resume
- Background recording support
- Automatic 30-second chunking for reliability
- Handle interruptions gracefully

### AI Enhancement
- Executive summaries in 2-3 sentences
- Action item extraction with owners and deadlines
- Key decision identification with context
- Unresolved questions flagged for follow-up

### Export Options
- Markdown with structured formatting
- PDF for professional distribution
- Direct integration with email and messaging apps
- JSON for system integration

## Status

🚧 Under active development for hackathon submission

### Completed
- ✅ Core recording infrastructure
- ✅ Meeting data model
- ✅ Audio chunking system

### In Progress
- 🔄 Real-time transcription
- 🔄 UI implementation
- 🔄 LFM2 integration

### Upcoming
- ⏳ Export functionality
- ⏳ Template system
- ⏳ Search capabilities