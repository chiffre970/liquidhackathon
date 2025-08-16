import Foundation

struct LFM2Prompts {
    // Unified comprehensive prompt for meeting analysis
    // Used for post-recording analysis and insights generation
    static func analyzeMeeting(transcript: String, userNotes: String?) -> String {
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
            "followUp": ["item needing follow-up", ...],
            "criticalInfo": "any urgent matters or warnings",
            "unresolvedTopics": ["topic requiring more discussion", ...],
            "meetingEffectiveness": "productive/neutral/unproductive"
        }
        
        Important:
        - Extract ALL action items mentioned
        - Identify decision makers when possible
        - Note any deadlines or time constraints
        - Flag critical items that need immediate attention
        - Assess meeting productivity
        - Return ONLY valid JSON, no markdown or explanation
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
        let criticalInfo: String?
        let unresolvedTopics: [String]
        let meetingEffectiveness: String
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
}