# Memory - Development Log

This file tracks key decisions and changes made during development.

## Project Rename
- Renamed entire project from PFMApp to "Vera" - personal finance assistant
- Updated all documentation, setup instructions, and file references
- Renamed PFMApp-source folder to Vera, PFMAppApp.swift to VeraApp.swift

## Project Setup
- Created basic iOS project structure with SwiftUI
- Set up tab navigation with Profile and Insights/Budget views
- Added LEAP SDK dependency in Package.swift
- Used green accent color for theme consistency
- Profile page shows import message as landing experience

## CSV Import Implementation
- Created Transaction model with ID, date, amount, description, counterparty, category
- Implemented CSVProcessor with flexible column detection for various CSV formats
- Added file import functionality with native iOS file picker
- Implemented transaction deduplication logic for merging multiple CSV files
- Created TransactionRow component showing amount (green/red), date, counterparty, category
- Added error handling with styled alerts matching green theme
- Fixed iOS file permission issue with startAccessingSecurityScopedResource()

## Xcode Project Setup
- Successfully created Xcode project with Core Data
- Basic app structure working - tabs, navigation, CSV import UI functional
- Need to copy updated source files and add missing InsightsView
