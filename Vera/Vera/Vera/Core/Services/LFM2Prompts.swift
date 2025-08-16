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