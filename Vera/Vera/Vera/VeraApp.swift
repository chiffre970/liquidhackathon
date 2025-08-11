//
//  VeraApp.swift
//  Vera
//
//  Created by Rueben Heuzenroeder on 8/8/2025.
//

import SwiftUI
import LeapSDK

@main
struct VeraApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var csvProcessor = CSVProcessor()
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var lfm2Manager = LFM2Manager.shared
    
    init() {
        // Attempt to initialize/register backends
        // This might help with XnnpackBackend registration
        print("🚀 Initializing Vera app...")
        
        #if DEBUG
        // Clear all data during development/testing - nothing persists
        print("🧹 DEBUG MODE: Clearing all stored data for fresh start...")
        DataManager.shared.clearAllData()
        print("✅ All data cleared for testing")
        #else
        // Production mode - preserve user data
        print("📊 Current stored transactions: \(DataManager.shared.transactions.count)")
        #endif
        
        // Some frameworks require explicit initialization
        // Try to trigger any static initialization
        _ = LeapSDK.Leap.self
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(csvProcessor)
                .environmentObject(dataManager)
                .environmentObject(lfm2Manager)
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
        }
    }
}
