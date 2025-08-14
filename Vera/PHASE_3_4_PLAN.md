# Phase 3 & 4 Implementation Plan - Vera Meeting Assistant

## Executive Summary
This document outlines the detailed implementation plan for Phases 3 and 4 of the Vera meeting assistant app. Phase 3 focuses on LFM2 AI enhancement capabilities, while Phase 4 covers export functionality and template systems.

## Phase 3: LFM2 AI Enhancement 

### 3.1 LFM2 Model Integration
**Priority: CRITICAL** | **Estimated Time: 2-3 days**

#### Prerequisites
- [ ] Verify LFM2-700M bundle is correctly included in project
- [ ] Review LEAP SDK documentation for iOS integration
- [ ] Confirm model memory requirements (~500MB)

#### Implementation Tasks

##### 3.1.1 Update LFM2Manager.swift
```swift
// Required functionality:
- Initialize LEAP SDK with model bundle
- Load model into memory with proper error handling
- Implement token generation with streaming support
- Add memory management for model lifecycle
- Handle model warm-up on first use
```

##### 3.1.2 Create Model Configuration
```swift
// Configuration needs:
- Max tokens: 2048 for summaries, 512 for classifications
- Temperature: 0.7 for creative tasks, 0.3 for extraction
- Top-p: 0.9
- Streaming: Enable for long-form generation
```

##### 3.1.3 Error Handling & Fallbacks
- Graceful degradation if model fails to load
- Fallback to basic text processing
- User notification of enhancement unavailability
- Retry mechanism for transient failures

### 3.2 Meeting Enhancement Service
**Priority: HIGH** | **Estimated Time: 2 days**

#### 3.2.1 Create MeetingEnhancementService.swift
```swift
class MeetingEnhancementService {
    // Core methods needed:
    func enhanceMeeting(_ meeting: Meeting) async
    func generateSummary(transcript: String, notes: String?) async -> String
    func extractActionItems(from transcript: String) async -> [ActionItem]
    func extractKeyDecisions(from transcript: String) async -> [KeyDecision]
    func identifyQuestions(from transcript: String) async -> [Question]
    func generateInsights(from transcript: String) async -> MeetingInsights
}
```

#### 3.2.2 Prompt Engineering

##### Summary Generation Prompt
```
You are analyzing a meeting transcript. Generate a comprehensive yet concise summary.

Meeting Transcript:
{transcript}

User Notes (if any):
{userNotes}

Instructions:
1. Create an executive summary (2-3 sentences)
2. List key discussion points (max 5 bullet points)
3. Highlight any critical information
4. Note any unresolved topics

Format as structured JSON:
{
  "executiveSummary": "...",
  "keyPoints": ["point1", "point2", ...],
  "criticalInfo": "...",
  "unresolvedTopics": ["topic1", ...]
}
```

##### Action Item Extraction Prompt
```
Extract ALL action items from this meeting transcript.

Transcript:
{transcript}

For each action item, identify:
- Task: Clear, actionable description
- Owner: Person responsible (if mentioned)
- Deadline: Any timeframe mentioned (today, tomorrow, next week, specific date)
- Priority: Infer from context (urgent, high, medium, low)
- Context: Brief note about why this task is needed

Return as JSON array:
[
  {
    "task": "...",
    "owner": "name or null",
    "deadline": "parsed date or null",
    "priority": "high|medium|low",
    "context": "..."
  }
]

Look for phrases like:
- "I'll do...", "Can you...", "We need to..."
- "By [date]", "Before [event]", "ASAP"
- "Action item:", "TODO:", "Next step:"
```

##### Key Decisions Extraction Prompt
```
Identify all decisions made during this meeting.

Transcript:
{transcript}

Extract decisions where the team:
- Agreed on something
- Chose between options
- Confirmed a plan
- Rejected an approach

For each decision:
{
  "decision": "What was decided",
  "context": "Why this decision was made",
  "impact": "Who/what this affects",
  "timestamp": "When in the meeting this occurred"
}

Look for: "decided", "agreed", "will go with", "confirmed", "chose"
```

##### Questions & Follow-ups Prompt
```
Identify questions and items needing follow-up from this meeting.

Transcript:
{transcript}

Find:
1. Unanswered questions
2. Items marked for research
3. Decisions pending information
4. Topics to revisit

Format:
{
  "question": "The question or item",
  "context": "Why this came up",
  "assignedTo": "Who should follow up (if mentioned)",
  "urgency": "high|medium|low"
}
```

### 3.3 Background Processing Integration
**Priority: MEDIUM** | **Estimated Time: 1 day**

#### 3.3.1 Update MeetingRecordingService
- Modify `processInBackground()` to call enhancement service
- Add progress tracking for long processing
- Implement chunked processing for long transcripts
- Add notification when enhancement completes

#### 3.3.2 Create BackgroundTaskScheduler
```swift
// Requirements:
- Use BGProcessingTask for enhancement
- Schedule when app goes to background
- Handle task expiration gracefully
- Update UI when task completes
```

### 3.4 Enhanced Meeting Detail View
**Priority: HIGH** | **Estimated Time: 2 days**

#### 3.4.1 Create Complete MeetingDetailView
Replace placeholder with full implementation:
- Tab interface for different sections
- Enhanced notes display with formatting
- Action items list with completion toggles
- Key decisions timeline
- Questions needing follow-up
- Original transcript view
- Audio playback controls

#### 3.4.2 Create Sub-Views
- `EnhancedNotesView`: Display AI-generated summary
- `ActionItemsView`: Interactive checklist with deadlines
- `DecisionsTimelineView`: Chronological decision list
- `QuestionsView`: Follow-up items tracker
- `TranscriptView`: Full searchable transcript

#### 3.4.3 Implement Interactions
- Mark action items complete
- Set reminders for deadlines
- Flag questions as resolved
- Add notes to decisions
- Search within transcript

## Phase 4: Export & Templates

### 4.1 Export Service Implementation
**Priority: MEDIUM** | **Estimated Time: 2 days**

#### 4.1.1 Create ExportService.swift
```swift
class ExportService {
    func exportAsMarkdown(_ meeting: Meeting) -> String
    func exportAsPlainText(_ meeting: Meeting) -> String
    func exportAsJSON(_ meeting: Meeting) -> Data
    func generatePDF(_ meeting: Meeting) -> Data
    func prepareEmailContent(_ meeting: Meeting) -> (subject: String, body: String)
}
```

#### 4.1.2 Markdown Template
```markdown
# {Meeting Title}
Date: {date} | Duration: {duration}

## Executive Summary
{enhanced summary}

## Key Decisions
- {decision 1} - {context}
- {decision 2} - {context}

## Action Items
- [ ] {task 1} - @{owner} - Due: {date}
- [ ] {task 2} - @{owner} - Due: {date}

## Questions for Follow-up
- {question 1} - {context}

## Meeting Notes
{user notes}

## Full Transcript
{transcript}

---
Generated by Vera Meeting Assistant
```

#### 4.1.3 PDF Generation
- Use iOS PDFKit framework
- Professional meeting minutes format
- Include company branding options
- Page headers with meeting info
- Formatted sections with proper spacing

#### 4.1.4 Share Sheet Integration
- Implement UIActivityViewController
- Support multiple export formats
- Quick share to common apps (Mail, Slack, etc.)
- Copy to clipboard option

### 4.2 Template System Enhancement
**Priority: LOW** | **Estimated Time: 1 day**

#### 4.2.1 Create TemplateManager
```swift
class TemplateManager {
    func loadDefaultTemplates() -> [MeetingTemplate]
    func loadCustomTemplates() -> [MeetingTemplate]
    func saveCustomTemplate(_ template: MeetingTemplate)
    func deleteTemplate(_ id: UUID)
    func applyTemplate(_ template: MeetingTemplate) -> String
}
```

#### 4.2.2 Expand Default Templates
Add more templates:
- **Sprint Planning**: Goals, Stories, Estimates, Assignments
- **Retrospective**: What went well, Improvements, Action items
- **Design Review**: Objectives, Feedback, Decisions, Next steps
- **Sales Call**: Prospect info, Pain points, Solution fit, Next steps
- **Interview**: Candidate info, Questions, Evaluation, Decision

#### 4.2.3 Custom Template Creator
- Template builder UI
- Section management (add/remove/reorder)
- Placeholder variables
- Save and name custom templates
- Import/export templates

### 4.3 Settings & Preferences
**Priority: MEDIUM** | **Estimated Time: 1 day**

#### 4.3.1 Implement SettingsView
- Recording quality settings
- Transcription language selection
- LFM2 enhancement preferences
- Export format defaults
- Notification preferences
- Data management (clear cache, delete old recordings)
- About section with version info

#### 4.3.2 User Preferences Storage
```swift
struct UserPreferences {
    var recordingQuality: AudioQuality
    var transcriptionLanguage: String
    var autoEnhance: Bool
    var defaultExportFormat: ExportFormat
    var actionItemReminders: Bool
    var keepAudioFiles: Bool
    var maxStorageDuration: Int // days
}
```

## Implementation Schedule

### Week 1: Core LFM2 Integration
- Day 1-2: LFM2Manager implementation and testing
- Day 3-4: MeetingEnhancementService with all prompts
- Day 5: Background processing integration

### Week 2: UI and Export
- Day 1-2: Complete MeetingDetailView with all sub-views
- Day 3-4: Export service with all formats
- Day 5: Settings view and preferences

### Week 3: Polish and Testing
- Day 1: Template system enhancements
- Day 2: Performance optimization
- Day 3-4: Comprehensive testing
- Day 5: Bug fixes and refinements

## Testing Requirements

### Unit Tests
- [ ] LFM2Manager initialization and error handling
- [ ] Enhancement service prompt responses
- [ ] Export format generation
- [ ] Template application

### Integration Tests
- [ ] End-to-end recording → transcription → enhancement
- [ ] Background processing completion
- [ ] Export and share functionality
- [ ] Settings persistence

### Performance Tests
- [ ] LFM2 processing time for various transcript lengths
- [ ] Memory usage during enhancement
- [ ] Background task completion rates
- [ ] Export generation speed

## Success Metrics

### Phase 3 Success Criteria
- ✅ LFM2 successfully enhances 95% of meetings
- ✅ Action items extracted with 80% accuracy
- ✅ Processing completes in <30s per hour of audio
- ✅ Background processing works reliably
- ✅ Enhanced detail view fully functional

### Phase 4 Success Criteria
- ✅ All export formats working correctly
- ✅ PDF generation produces professional output
- ✅ Share sheet integration seamless
- ✅ Template system intuitive and flexible
- ✅ Settings properly control app behavior

## Risk Mitigation

### Technical Risks
1. **LFM2 Memory Issues**
   - Mitigation: Implement model unloading when not in use
   - Fallback: Process in smaller chunks

2. **Background Processing Limits**
   - Mitigation: Save state for resumption
   - Fallback: Process when app returns to foreground

3. **Large Transcript Performance**
   - Mitigation: Implement streaming/chunked processing
   - Fallback: Limit enhancement to first N minutes

### User Experience Risks
1. **Slow Enhancement Processing**
   - Mitigation: Show progress indicators
   - Fallback: Allow viewing meeting before enhancement

2. **Inaccurate Extraction**
   - Mitigation: Allow manual editing of extracted items
   - Fallback: Provide "report issue" feature

## Dependencies

### External Dependencies
- LEAP SDK (latest version)
- LFM2-700M model bundle
- PDFKit (iOS system framework)

### Internal Dependencies
- Core Data models must be stable
- Recording service must be reliable
- Transcription must be accurate

## Next Steps

1. **Immediate Actions**
   - Review LEAP SDK documentation
   - Set up development environment for LFM2
   - Create test meetings for enhancement testing

2. **Team Coordination**
   - Assign developers to specific components
   - Set up daily progress check-ins
   - Create shared testing document

3. **Documentation Needs**
   - API documentation for services
   - User guide for new features
   - Troubleshooting guide for common issues

## Conclusion

Phases 3 and 4 will transform Vera from a basic recording app into an intelligent meeting assistant. The LFM2 integration is the critical path item that enables all advanced features. With proper implementation and testing, these phases will deliver significant value to users by automating the tedious parts of meeting documentation and follow-up.