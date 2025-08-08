# Vera - Personal Finance Assistant

A privacy-first personal finance management iOS app built with Liquid AI's LFM2 model for local, on-device transaction analysis and budgeting.

## Overview

This app leverages Liquid AI's LEAP Devkit to provide completely local financial analysis without compromising user privacy. Users can import CSV transaction files, get AI-powered insights through categorization and spending analysis, and receive personalized budget recommendations.

## Key Features

- **Privacy-First**: 100% local processing using LFM2 - no data leaves your device
- **Intelligent Categorization**: AI-powered transaction categorization from flexible CSV formats
- **Visual Insights**: Sankey diagrams showing income flow and spending breakdown
- **Smart Budgeting**: AI-assisted budget planning with goal-based recommendations
- **Multi-File Support**: Import and merge multiple CSV files seamlessly

## App Structure

### Three Main Screens:
1. **Transactions Page**: CSV import, view uploaded files, and browse categorized transactions
2. **Insights Page**: Monthly cash flow visualization with Sankey diagrams and AI-powered spending analysis
3. **Budget Page**: Interactive chat interface for budget negotiation and finalized budget summaries

## Technical Stack

- **Platform**: iOS (Swift, SwiftUI)
- **AI Model**: Liquid AI LFM2 (700M parameters, bundled locally)
- **Data Storage**: Core Data for local persistence
- **Visualization**: Custom Sankey diagram implementation
- **CSV Processing**: Row-by-row processing with real-time progress

## Getting Started

### Prerequisites
- iOS 15.0+ (iOS 17.6+ recommended)
- Xcode 15.0+ with Swift 5.9+
- 4GB+ RAM recommended for optimal model performance

### Installation
1. Clone the repository
2. Open in Xcode
3. The LEAP SDK and LFM2 model are bundled with the project
4. Build and run on device (simulator performance may be limited)

## Project Timeline
- **Target**: 10 days development cycle
- **Hackathon**: Liquid AI Hackathon submission
- **App Name**: Vera - your personal finance assistant

## Privacy & Security
- All transaction data remains on device
- No network requests for AI processing
- Local Core Data storage only
- No user tracking or analytics
