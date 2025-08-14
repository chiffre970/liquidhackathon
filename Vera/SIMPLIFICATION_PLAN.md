# App Simplification Plan - Notes App Style

## Current State (Too Complex)
```
TabView
├── Record Tab (MeetingView)
│   ├── Note editor
│   ├── Recording controls
│   └── Templates
├── Meetings Tab (MeetingListView)
│   ├── Meeting list
│   └── MeetingDetailView (separate notes view)
└── Settings Tab
```

## Target State (Apple Notes Style)
```
NavigationView
├── NoteListView (Default view - scrollable list)
│   ├── Search bar
│   ├── Note cells (title, date, preview)
│   └── New Note button
└── SingleNoteView (When note selected)
    ├── Note editor
    ├── Recording controls (bottom toolbar)
    └── AI enhance button (toolbar)

## Implementation Plan

### Phase 1: Create Note List View (Like Apple Notes)
1. **NoteListView.swift**
   - Scrollable list of all notes
   - Each cell shows: Title, Date, First line preview
   - Search bar at top
   - New Note button (bottom right floating or toolbar)
   - Swipe to delete

2. **SingleNoteView.swift**
   - Full-screen note editor
   - Combined manual notes + transcript display
   - Bottom toolbar with controls
   - Back button to return to list

3. **Navigation Flow**
```
App Launch → NoteListView
    ↓
Tap Note → SingleNoteView
    ↓
Edit/Record/Enhance
    ↓
Back → NoteListView
```

### Phase 3: Remove Components
- Delete TabView structure
- Remove MeetingListView
- Remove MeetingDetailView  
- Remove separate MeetingRowView
- Simplify ContentView to just NoteView

### Phase 4: Data Flow
```
NoteView
  ├── @StateObject recordingService
  ├── @State currentMeeting (selected note)
  ├── @State showNoteSelector
  └── @State noteText (combined notes + transcript)
```

## Simplified Interface Elements

### Top Navigation Bar
```
[Note Title ▼]                    [Share]
```

### Main Content Area
```
┌────────────────────────────────┐
│                                │
│     Note Editor                │
│     (User notes + Transcript)  │
│                                │
│                                │
│                                │
└────────────────────────────────┘
```

### Bottom Controls
```
[●] Record     [✨] AI Enhance
```

## User Interactions

1. **Select Note**: Tap title → dropdown menu → pick note
2. **New Note**: Dropdown → "New Note" → clears editor
3. **Record**: Tap record → starts recording → transcript appears
4. **Enhance**: Tap AI → processes with LFM2 → updates note
5. **Share**: Top right → export options

## Benefits
- Single page = less cognitive load
- All notes accessible from one place
- Recording integrated into note-taking
- No navigation confusion
- Faster access to everything

## Migration Steps
1. Build new NoteView with all functionality
2. Test thoroughly
3. Remove old views
4. Update ContentView
5. Clean up unused code

## Questions for User
- Should note selector be dropdown or slide-out panel?
- Keep templates or remove for simplicity?
- Auto-save frequency preference?
- Should AI enhancement replace or append to notes?