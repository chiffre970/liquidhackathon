import UserNotifications
import Foundation

class NotificationManager {
    static let shared = NotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func scheduleNotification(for thought: Thought) async {
        guard let category = thought.category else { return }
        
        let content = UNMutableNotificationContent()
        
        switch category {
        case .action(let deadline, let priority):
            content.title = "Action Reminder"
            content.body = thought.summary
            content.sound = .default
            content.categoryIdentifier = "ACTION"
            
            if priority == .high {
                content.interruptionLevel = .timeSensitive
            }
            
            let trigger: UNNotificationTrigger
            if let deadline = deadline {
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: deadline
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            } else {
                let timeInterval = getTimeInterval(for: priority)
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            }
            
            let request = UNNotificationRequest(
                identifier: thought.id.uuidString,
                content: content,
                trigger: trigger
            )
            
            try? await notificationCenter.add(request)
            
        case .thought(let theme):
            content.title = "Thought Insight"
            content.body = "\(theme.capitalized): \(thought.summary)"
            content.sound = .default
            content.categoryIdentifier = "THOUGHT"
            
            let randomDelay = TimeInterval.random(in: 3600...86400)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: randomDelay, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: thought.id.uuidString,
                content: content,
                trigger: trigger
            )
            
            try? await notificationCenter.add(request)
        }
    }
    
    private func getTimeInterval(for priority: Category.Priority) -> TimeInterval {
        switch priority {
        case .high:
            return 3600
        case .medium:
            return 86400
        case .low:
            return 259200
        }
    }
    
    func cancelNotification(for thoughtId: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [thoughtId.uuidString])
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }
}