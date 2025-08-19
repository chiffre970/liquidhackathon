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
        
        // Set navigation bar appearance globally
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        appearance.shadowColor = nil
        
        // Set title to light grey color with shadow
        let titleColor = UIColor(red: 211/255, green: 227/255, blue: 240/255, alpha: 1.0) // #D3E3F0
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black
        shadow.shadowOffset = CGSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 0
        
        appearance.largeTitleTextAttributes = [
            .foregroundColor: titleColor,
            .shadow: shadow
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: titleColor,
            .shadow: shadow
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(red: 165/255, green: 178/255, blue: 190/255, alpha: 1.0) // #A5B2BE
        
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
