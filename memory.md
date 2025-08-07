# Memory - Development Log

This file tracks key decisions and changes made during development.

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
