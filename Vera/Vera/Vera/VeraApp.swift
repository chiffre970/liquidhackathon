//
//  VeraApp.swift
//  Vera
//
//  Created by Rueben Heuzenroeder on 8/8/2025.
//

import SwiftUI
import CoreData
import UIKit

@main
struct VeraApp: App {
    @StateObject private var lfm2Manager = LFM2Manager.shared
    private let persistenceController = PersistenceController.shared
    
    init() {
        print("🚀 Initializing Vera Meeting Notes...")
        
        // Clean up orphaned audio files on launch
        let context = persistenceController.container.viewContext
        Task {
            await MainActor.run {
                StorageManager.shared.cleanupOrphanedAudioFiles(context: context)
            }
        }
        
        // BackgroundProcessor.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(lfm2Manager)
                .preferredColorScheme(.light)
                .task {
                    await lfm2Manager.initialize()
                }
                // .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                //     BackgroundProcessor.shared.endCurrentSession()
                //     BackgroundProcessor.shared.scheduleBackgroundProcessing()
                // }
        }
    }
}
