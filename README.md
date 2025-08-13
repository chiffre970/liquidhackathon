# Vera - AI Thought Organizer

An elegant iOS app that captures your spoken thoughts and intelligently organizes them using on-device AI.

## Vision

Vera transforms fleeting thoughts into organized, actionable insights. Simply tap the ethereal particle orb, speak your mind, and let the app transcribe and categorize your thoughts in the background using the powerful LFM2 700M model.

## Features

- **Effortless Capture**: Tap floating particles to start/stop recording
- **Automatic Transcription**: Apple's Speech framework converts speech to text
- **Intelligent Organization**: LFM2 categorizes thoughts as Actions or Ideas
- **Smart Reminders**: Action items trigger task-based notifications, thoughts trigger content-based insights
- **Beautiful Visualization**: Ethereal particle orb with pink/purple/blue/red fluid animations
- **Complete Privacy**: All processing happens on-device, no cloud dependencies

## Technical Stack

- **Platform**: iOS 15.0+
- **UI Framework**: SwiftUI
- **AI Model**: LFM2 700M (via LEAP SDK)
- **Speech**: Apple Speech Framework
- **Audio**: AVFoundation
- **Storage**: Core Data
- **Notifications**: UserNotifications

## Architecture

```
Vera/
├── Core/
│   ├── Models/         # Thought, Session, Category
│   ├── Services/       # Audio, Transcription, AI Processing
│   └── Storage/        # Core Data persistence
├── UI/
│   ├── Particles/      # Orb visualization
│   ├── Recording/      # Recording interface
│   └── Library/        # Thought browsing (future)
└── Resources/
    └── LFM2/           # 700M model bundle
```

## Privacy First

- No network requests for processing
- All AI inference on-device
- No analytics or tracking
- Secure local storage only

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

## Status

🚧 Under active development for hackathon submission
