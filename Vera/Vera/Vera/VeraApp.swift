//
//  VeraApp.swift
//  Vera
//
//  Created by Rueben Heuzenroeder on 8/8/2025.
//

import SwiftUI

@main
struct VeraApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var csvProcessor = CSVProcessor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(csvProcessor)
        }
    }
}
