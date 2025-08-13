//
//  VeraApp.swift
//  Vera
//
//  Created by Rueben Heuzenroeder on 8/8/2025.
//

import SwiftUI

@main
struct VeraApp: App {
    @StateObject private var lfm2Manager = LFM2Manager.shared
    
    init() {
        print("🚀 Initializing Vera Thought Organizer...")
        
        BackgroundProcessor.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(lfm2Manager)
                .preferredColorScheme(.light)
                .task {
                    await lfm2Manager.initialize()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    BackgroundProcessor.shared.endCurrentSession()
                    BackgroundProcessor.shared.scheduleBackgroundProcessing()
                }
        }
    }
}
