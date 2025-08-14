import Foundation
import BackgroundTasks
import CoreData

class BackgroundProcessor: ObservableObject {
    static let shared = BackgroundProcessor()
    
    private var persistentContainer: NSPersistentContainer {
        PersistenceController.shared.container
    }
    private var currentSession: Session?
    
    private init() {
        // Use the shared PersistenceController instead of creating a new container
    }
    
    func processThought(transcription: String, audioURL: URL) async {
        let context = persistentContainer.viewContext
        
        if currentSession == nil {
            currentSession = Session.createNew(in: context)
        }
        
        guard let session = currentSession else { return }
        
        let thought = Thought(context: context)
        thought.rawTranscription = transcription
        thought.sessionId = session.id
        
        do {
            let processedData = await LFM2Processor.shared.processThought(transcription: transcription)
            
            thought.summary = processedData.summary
            thought.category = processedData.category
            thought.tagsArray = processedData.tags
            
            session.thoughtCount += 1
            
            try context.save()
            
            scheduleNotification(for: thought)
            
            try? FileManager.default.removeItem(at: audioURL)
            
        } catch {
            print("Failed to process thought: \(error)")
        }
    }
    
    func endCurrentSession() {
        guard let session = currentSession else { return }
        
        session.end()
        
        Task {
            let thoughts = try? persistentContainer.viewContext.fetch(
                Thought.fetchRequestForSession(session.id)
            )
            
            if let thoughts = thoughts, !thoughts.isEmpty {
                let summary = await LFM2Processor.shared.summarizeSession(thoughts: thoughts)
                session.overallSummary = summary
            }
            
            try? persistentContainer.viewContext.save()
        }
        
        currentSession = nil
    }
    
    private func scheduleNotification(for thought: Thought) {
        Task {
            await NotificationManager.shared.scheduleNotification(for: thought)
        }
    }
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.vera.thoughtprocessing",
            using: nil
        ) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
    }
    
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            let context = persistentContainer.newBackgroundContext()
            let request = Thought.fetchRequest()
            request.predicate = NSPredicate(format: "summary == nil")
            
            do {
                let unprocessedThoughts = try context.fetch(request)
                
                for thought in unprocessedThoughts {
                    let processedData = await LFM2Processor.shared.processThought(
                        transcription: thought.rawTranscription
                    )
                    
                    thought.summary = processedData.summary
                    thought.category = processedData.category
                    thought.tagsArray = processedData.tags
                }
                
                try context.save()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.vera.thoughtprocessing")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
}