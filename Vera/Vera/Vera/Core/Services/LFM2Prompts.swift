import Foundation

struct LFM2Prompts {
    // SINGLE comprehensive prompt for post-recording analysis
    // This runs ONCE when user hits "End Recording"
    static func meetingAnalysis(transcript: String, userNotes: String?) -> String {
        """
        Analyze this complete meeting recording and provide comprehensive insights.
        
        Meeting Transcript:
        \(transcript)
        
        User Notes:
        \(userNotes ?? "None provided")
        
        Generate a JSON response with the following structure:
        {
            "executiveSummary": "2-3 sentence overview of the entire meeting",
            "keyPoints": ["main point 1", "main point 2", ...],
            "actionItems": [
                {"task": "specific action", "owner": "person name", "deadline": "date if mentioned", "priority": "high/medium/low"}
            ],
            "decisions": [
                {"decision": "what was decided", "context": "why/how", "impact": "consequences"}
            ],
            "questions": [
                {"question": "unresolved question", "assignedTo": "person/team", "urgency": "high/medium/low"}
            ],
            "risks": ["identified risk 1", "identified risk 2"],
            "followUp": ["item needing follow-up", ...]
        }
        
        Important:
        - Extract ALL action items mentioned
        - Identify decision makers when possible
        - Note any deadlines or time constraints
        - Flag critical items that need immediate attention
        - Return ONLY valid JSON, no markdown or explanation
        """
    }
    
    // Focused prompt for extracting only action items
    static func extractActionItems(transcript: String) -> String {
        """
        Extract all action items from this meeting transcript:
        \(transcript)
        
        For each action item identify:
        - Task description (clear and actionable)
        - Owner (person responsible if mentioned)
        - Deadline (if any timeframe mentioned)
        - Priority (high/medium/low based on context)
        
        Return as JSON array:
        [
            {
                "task": "specific actionable task",
                "owner": "person name or null",
                "deadline": "ISO8601 date or null",
                "priority": "high/medium/low",
                "context": "brief context about why this is needed"
            }
        ]
        
        Return ONLY the JSON array, no explanation.
        """
    }
    
    // Focused prompt for extracting key decisions
    static func extractDecisions(transcript: String) -> String {
        """
        Identify all key decisions made in this meeting:
        \(transcript)
        
        For each decision extract:
        - The decision that was made
        - Context and rationale
        - Impact or consequences
        - Who made or approved the decision (if mentioned)
        
        Return as JSON array:
        [
            {
                "decision": "what was decided",
                "context": "why this decision was made",
                "impact": "consequences or expected outcomes",
                "decisionMaker": "person/team or null",
                "timestamp": "when in meeting if identifiable"
            }
        ]
        
        Return ONLY the JSON array, no explanation.
        """
    }
    
    // Focused prompt for identifying questions and uncertainties
    static func extractQuestions(transcript: String) -> String {
        """
        Identify questions raised and unresolved items in this meeting:
        \(transcript)
        
        For each question or uncertainty:
        - The question or uncertain item
        - Context around why it came up
        - Who should follow up (if mentioned)
        - Urgency level
        
        Return as JSON array:
        [
            {
                "question": "the unresolved question",
                "context": "why this needs answering",
                "assignedTo": "person/team responsible or null",
                "urgency": "high/medium/low",
                "needsFollowUp": true/false
            }
        ]
        
        Return ONLY the JSON array, no explanation.
        """
    }
    
    // Enhanced summary prompt with better structure
    static func generateEnhancedSummary(transcript: String, userNotes: String?) -> String {
        """
        Create a structured meeting summary from this transcript:
        \(transcript)
        
        Additional Notes:
        \(userNotes ?? "None")
        
        Generate a professional summary with:
        1. Executive Summary (2-3 sentences capturing the essence)
        2. Key Discussion Points (maximum 5, most important)
        3. Outcomes and Next Steps
        4. Critical Information or Warnings
        5. Topics Requiring Follow-up
        
        Return as JSON:
        {
            "executiveSummary": "concise 2-3 sentence overview",
            "keyPoints": ["point 1", "point 2", ...],
            "outcomes": ["outcome 1", "outcome 2", ...],
            "criticalInfo": "any urgent matters or warnings",
            "unresolvedTopics": ["topic 1", "topic 2", ...],
            "meetingEffectiveness": "productive/neutral/unproductive",
            "suggestedFollowUp": "recommended next meeting focus"
        }
        
        Return ONLY valid JSON, no explanation.
        """
    }
    
    // Template-based prompt for specific meeting types
    static func analyzeWithTemplate(transcript: String, template: String, userNotes: String?) -> String {
        switch template {
        case "standup":
            return standupAnalysis(transcript: transcript)
        case "one-on-one":
            return oneOnOneAnalysis(transcript: transcript, notes: userNotes)
        case "client":
            return clientMeetingAnalysis(transcript: transcript, notes: userNotes)
        case "brainstorm":
            return brainstormAnalysis(transcript: transcript)
        case "review":
            return reviewMeetingAnalysis(transcript: transcript)
        default:
            return meetingAnalysis(transcript: transcript, userNotes: userNotes)
        }
    }
    
    // Stand-up specific analysis
    private static func standupAnalysis(transcript: String) -> String {
        """
        Analyze this stand-up meeting:
        \(transcript)
        
        Extract for each participant:
        - What they completed yesterday
        - What they're working on today
        - Any blockers or issues
        
        Return as JSON:
        {
            "participants": [
                {
                    "name": "participant name",
                    "yesterday": ["task 1", "task 2"],
                    "today": ["task 1", "task 2"],
                    "blockers": ["blocker 1", "blocker 2"],
                    "needsHelp": true/false
                }
            ],
            "teamBlockers": ["shared blocker 1", "shared blocker 2"],
            "criticalIssues": ["urgent issue 1"],
            "teamMorale": "high/medium/low"
        }
        
        Return ONLY valid JSON.
        """
    }
    
    // One-on-one meeting analysis
    private static func oneOnOneAnalysis(transcript: String, notes: String?) -> String {
        """
        Analyze this one-on-one meeting:
        \(transcript)
        
        Notes: \(notes ?? "None")
        
        Extract:
        - Topics discussed
        - Feedback given/received
        - Goals and commitments
        - Concerns raised
        - Action items for both parties
        
        Return as JSON:
        {
            "topics": ["topic 1", "topic 2"],
            "feedback": {
                "positive": ["feedback 1", "feedback 2"],
                "constructive": ["feedback 1", "feedback 2"]
            },
            "goals": ["goal 1", "goal 2"],
            "concerns": ["concern 1", "concern 2"],
            "actionItems": {
                "manager": ["action 1", "action 2"],
                "employee": ["action 1", "action 2"]
            },
            "followUpNeeded": true/false,
            "nextMeetingFocus": "suggested focus for next meeting"
        }
        
        Return ONLY valid JSON.
        """
    }
    
    // Client meeting analysis
    private static func clientMeetingAnalysis(transcript: String, notes: String?) -> String {
        """
        Analyze this client meeting:
        \(transcript)
        
        Notes: \(notes ?? "None")
        
        Extract:
        - Client needs and requirements
        - Commitments made
        - Questions from client
        - Next steps
        - Risks or concerns
        
        Return as JSON:
        {
            "clientNeeds": ["need 1", "need 2"],
            "commitments": [
                {"commitment": "what was promised", "deadline": "when", "owner": "who"}
            ],
            "clientQuestions": [
                {"question": "client question", "answered": true/false, "followUp": "if unanswered"}
            ],
            "nextSteps": ["step 1", "step 2"],
            "risks": ["risk 1", "risk 2"],
            "relationshipHealth": "strong/good/neutral/concerning",
            "opportunitiesIdentified": ["opportunity 1", "opportunity 2"]
        }
        
        Return ONLY valid JSON.
        """
    }
    
    // Brainstorming session analysis
    private static func brainstormAnalysis(transcript: String) -> String {
        """
        Analyze this brainstorming session:
        \(transcript)
        
        Extract:
        - Ideas generated
        - Most promising concepts
        - Ideas to explore further
        - Rejected ideas and why
        
        Return as JSON:
        {
            "allIdeas": ["idea 1", "idea 2", ...],
            "topIdeas": [
                {"idea": "promising idea", "proposedBy": "person", "potential": "why promising"}
            ],
            "toExplore": [
                {"idea": "idea to research", "assignedTo": "person", "nextStep": "what to do"}
            ],
            "rejected": [
                {"idea": "rejected idea", "reason": "why rejected"}
            ],
            "sessionProductivity": "highly productive/productive/moderate/low",
            "nextSession": "recommended focus for follow-up"
        }
        
        Return ONLY valid JSON.
        """
    }
    
    // Review/retrospective meeting analysis
    private static func reviewMeetingAnalysis(transcript: String) -> String {
        """
        Analyze this review/retrospective meeting:
        \(transcript)
        
        Extract:
        - What went well
        - What could be improved
        - Lessons learned
        - Action items for improvement
        
        Return as JSON:
        {
            "wentWell": ["positive 1", "positive 2", ...],
            "needsImprovement": ["area 1", "area 2", ...],
            "lessonsLearned": ["lesson 1", "lesson 2", ...],
            "improvements": [
                {"improvement": "what to change", "owner": "who", "timeline": "when"}
            ],
            "teamSentiment": "positive/neutral/negative",
            "keyMetrics": {
                "discussed": ["metric 1", "metric 2"],
                "targets": ["target 1", "target 2"]
            }
        }
        
        Return ONLY valid JSON.
        """
    }
}

// Response type definitions for JSON parsing
extension LFM2Prompts {
    struct MeetingAnalysisResponse: Codable {
        let executiveSummary: String
        let keyPoints: [KeyPoint]
        let actionItems: [ActionItem]
        let decisions: [Decision]
        let questions: [Question]
        let risks: [Risk]
        let followUp: [FollowUpItem]
    }
    
    struct KeyPoint: Codable {
        let point: String?
        let details: String?
        
        // Support both string and object format
        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(),
               let stringValue = try? container.decode(String.self) {
                self.point = stringValue
                self.details = nil
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.point = try container.decodeIfPresent(String.self, forKey: .point)
                self.details = try container.decodeIfPresent(String.self, forKey: .details)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case point, details
        }
    }
    
    struct Risk: Codable {
        let risk: String?
        let impact: String?
        let mitigation: String?
        
        // Support both string and object format
        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(),
               let stringValue = try? container.decode(String.self) {
                self.risk = stringValue
                self.impact = nil
                self.mitigation = nil
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.risk = try container.decodeIfPresent(String.self, forKey: .risk)
                self.impact = try container.decodeIfPresent(String.self, forKey: .impact)
                self.mitigation = try container.decodeIfPresent(String.self, forKey: .mitigation)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case risk, impact, mitigation
        }
    }
    
    struct FollowUpItem: Codable {
        let item: String?
        let dueDate: String?
        let priority: String?
        
        // Support both string and object format
        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(),
               let stringValue = try? container.decode(String.self) {
                self.item = stringValue
                self.dueDate = nil
                self.priority = nil
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.item = try container.decodeIfPresent(String.self, forKey: .item)
                self.dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
                self.priority = try container.decodeIfPresent(String.self, forKey: .priority)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case item, dueDate, priority
        }
    }
    
    struct ActionItem: Codable {
        let task: String
        let owner: String?
        let deadline: String?
        let priority: String
        let context: String?
    }
    
    struct Decision: Codable {
        let decision: String
        let context: String
        let impact: String
        let decisionMaker: String?
        let timestamp: String?
    }
    
    struct Question: Codable {
        let question: String
        let context: String
        let assignedTo: String?
        let urgency: String
        let needsFollowUp: Bool
    }
    
    struct EnhancedSummaryResponse: Codable {
        let executiveSummary: String
        let keyPoints: [String]
        let outcomes: [String]
        let criticalInfo: String?
        let unresolvedTopics: [String]
        let meetingEffectiveness: String
        let suggestedFollowUp: String
    }
}