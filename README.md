# Vera - Take notes and summarise meetings, powered by LFM2

An intelligent iOS native app that records meetings, transcribes conversations in real-time, and uses on-device AI to extract actionable insights.

## Vision

Vera turns meetings into structured, useful information. Simply tap to record, and let the app transcribe conversations and extract action items, key decisions, and important questions using the powerful LFM2 1.2B model - all processed locally on your device.

## Key Features

- **Audio Deduplication**: Apple's Speech framework automatically chunks every 30s as well as during natural pauses, so I developed a system to manage and deduplicate the chunks into one cohesive transcript
- **LFM2 Pipeline**: I experimented with a few different approaches to using LFM2, including multi-stage processing, and different model sizes, but in the end most effective was using 1.2B with a simple prompt and give the model the latitude to use data as it sees fit. It would have been good to fine tune the model, or in the future use the 1.2B-Extract model.
- **Complete Privacy**: All processing happens on-device, no cloud dependencies
- **Note taking**: Add personal notes to the AI summary

## Functionality

- **Real-Time Transcription**: Apple's Speech framework converts speech to text as you record
- **Intelligent Enhancement**: LFM2 generates summaries, extracts action items, and identifies key decisions
- **Complete Privacy**: All processing happens on-device, no cloud dependencies
- **Note taking**: Add personal notes to the AI summary

## Technical Stack

- **Platform**: iOS 15.0+
- **Language**: Swift
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