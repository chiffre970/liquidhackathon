import Foundation

class ActionItemExtractor {
    private let lfm2Manager = LFM2Manager.shared
    
    private let actionPhrases = [
        "I'll", "I will", "We'll", "We will",
        "Can you", "Could you", "Would you",
        "Please", "Make sure", "Don't forget",
        "Action item", "TODO", "To do",
        "Next step", "Follow up", "Check on",
        "Need to", "Have to", "Must",
        "Should", "Let's", "Going to"
    ]
    
    private let deadlinePhrases = [
        "by", "before", "until", "deadline",
        "due", "ASAP", "urgent", "immediately",
        "today", "tomorrow", "next week",
        "next month", "Monday", "Tuesday",
        "Wednesday", "Thursday", "Friday",
        "end of day", "EOD", "COB"
    ]
    
    func extractFromTranscript(_ transcript: String) async throws -> [ActionItem] {
        let aiExtracted = try await extractWithAI(transcript)
        
        let rulesBasedItems = extractWithRules(transcript)
        
        return mergeAndDeduplicate(aiItems: aiExtracted, ruleItems: rulesBasedItems)
    }
    
    private func extractWithAI(_ transcript: String) async throws -> [ActionItem] {
        let prompt = """
        Extract action items from this meeting transcript. Be thorough and capture all commitments.
        
        Transcript:
        \(transcript)
        
        For each action item, provide:
        - task: Specific, actionable description
        - owner: Person responsible (null if not specified)
        - deadline: ISO8601 date (null if not specified)
        - priority: "urgent", "high", "medium", or "low"
        - context: Why this task is important
        
        Focus on:
        1. Direct commitments ("I'll send the report")
        2. Requests ("Can you review this?")
        3. Decisions requiring action ("We need to hire someone")
        4. Follow-ups mentioned ("Check with finance team")
        
        Return as JSON array.
        """
        
        let responses = try await lfm2Manager.generateJSON(
            prompt: prompt,
            configuration: .extraction,
            responseType: [LFM2Manager.ActionItemResponse].self
        )
        
        return responses.map { response in
            ActionItem(
                task: response.task,
                owner: response.owner,
                deadline: response.deadline.flatMap { ISO8601DateFormatter().date(from: $0) },
                isCompleted: false,
                priority: ActionItem.Priority(rawValue: response.priority) ?? .medium,
                context: response.context
            )
        }
    }
    
    private func extractWithRules(_ transcript: String) -> [ActionItem] {
        var items: [ActionItem] = []
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        for sentence in sentences {
            let lowercased = sentence.lowercased()
            
            if actionPhrases.contains(where: { lowercased.contains($0) }) {
                let task = cleanupTask(sentence)
                let owner = extractOwner(from: sentence)
                let deadline = extractDeadline(from: sentence)
                let priority = determinePriority(from: sentence)
                
                if !task.isEmpty {
                    items.append(ActionItem(
                        task: task,
                        owner: owner,
                        deadline: deadline,
                        isCompleted: false,
                        priority: priority,
                        context: nil
                    ))
                }
            }
        }
        
        return items
    }
    
    private func cleanupTask(_ sentence: String) -> String {
        var cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for phrase in actionPhrases {
            if let range = cleaned.range(of: phrase, options: .caseInsensitive) {
                cleaned = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        cleaned = cleaned.replacingOccurrences(of: "^(to |that |the )", with: "", options: .regularExpression)
        
        if cleaned.count > 200 {
            cleaned = String(cleaned.prefix(200)) + "..."
        }
        
        return cleaned.capitalizingFirstLetter()
    }
    
    private func extractOwner(from sentence: String) -> String? {
        let patterns = [
            "@([A-Za-z]+)",
            "\\b([A-Z][a-z]+)\\b(?=.*(?:will|can|should|needs to))",
            "assigned to ([A-Za-z]+)",
            "owner:?\\s*([A-Za-z]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(sentence.startIndex..<sentence.endIndex, in: sentence)
                if let match = regex.firstMatch(in: sentence, options: [], range: range) {
                    if let ownerRange = Range(match.range(at: 1), in: sentence) {
                        return String(sentence[ownerRange])
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractDeadline(from sentence: String) -> Date? {
        let lowercased = sentence.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        if lowercased.contains("asap") || lowercased.contains("urgent") || lowercased.contains("immediately") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        
        if lowercased.contains("today") || lowercased.contains("eod") || lowercased.contains("cob") {
            return calendar.dateInterval(of: .day, for: now)?.end
        }
        
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        
        if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }
        
        if lowercased.contains("next month") {
            return calendar.date(byAdding: .month, value: 1, to: now)
        }
        
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for (index, weekday) in weekdays.enumerated() {
            if lowercased.contains(weekday) {
                return nextWeekday(index + 1)
            }
        }
        
        return nil
    }
    
    private func nextWeekday(_ weekday: Int) -> Date? {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        
        var daysToAdd = weekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: today)
    }
    
    private func determinePriority(from sentence: String) -> ActionItem.Priority {
        let lowercased = sentence.lowercased()
        
        if lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("critical") {
            return .urgent
        }
        
        if lowercased.contains("important") || lowercased.contains("priority") || lowercased.contains("must") {
            return .high
        }
        
        if lowercased.contains("should") || lowercased.contains("need") {
            return .medium
        }
        
        return .low
    }
    
    private func mergeAndDeduplicate(aiItems: [ActionItem], ruleItems: [ActionItem]) -> [ActionItem] {
        var merged = aiItems
        
        for ruleItem in ruleItems {
            let isDuplicate = aiItems.contains { aiItem in
                similarityScore(aiItem.task, ruleItem.task) > 0.7
            }
            
            if !isDuplicate {
                merged.append(ruleItem)
            }
        }
        
        return merged.sorted { item1, item2 in
            if item1.priority.rawValue != item2.priority.rawValue {
                return priorityValue(item1.priority) > priorityValue(item2.priority)
            }
            
            if let date1 = item1.deadline, let date2 = item2.deadline {
                return date1 < date2
            }
            
            return item1.deadline != nil && item2.deadline == nil
        }
    }
    
    private func similarityScore(_ str1: String, _ str2: String) -> Double {
        let words1 = Set(str1.lowercased().split(separator: " "))
        let words2 = Set(str2.lowercased().split(separator: " "))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }
    
    private func priorityValue(_ priority: ActionItem.Priority) -> Int {
        switch priority {
        case .urgent: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

private extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}