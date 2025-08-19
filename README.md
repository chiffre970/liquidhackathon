# Vera - AI-Powered Meeting Assistant

An intelligent iOS app that records meetings, transcribes conversations in real-time, and uses on-device AI to extract actionable insights.

## Vision

Vera turns meetings into structured, useful information. Simply tap to record, and let the app transcribe conversations and extract action items, key decisions, and important questions using the powerful LFM2 1.2B model - all processed locally on your device.

## Features

- **Real-Time Transcription**: Apple's Speech framework converts speech to text as you record
- **Intelligent Enhancement**: LFM2 generates summaries, extracts action items, and identifies key decisions
- **Complete Privacy**: All processing happens on-device, no cloud dependencies

## Technical Stack

- **Platform**: iOS 15.0+
- **UI Framework**: SwiftUI
- **AI Model**: LFM2 1.2B (via LEAP SDK)
- **Speech**: Apple Speech Framework
- **Audio**: AVFoundation

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
- ~800MB free space for LFM2 model

### Setup
```bash
xcodebuild -project Vera.xcodeproj -scheme Vera -sdk iphoneos
```
Thanks to Liquid for hosting the hackathon