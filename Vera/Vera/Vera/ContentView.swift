//
//  ContentView.swift
//  Vera
//
//  Created by Rueben Heuzenroeder on 8/8/2025.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var csvProcessor: CSVProcessor
    @EnvironmentObject var lfm2Manager: LFM2Manager
    
    var body: some View {
        ZStack {
            Color.veraWhite.ignoresSafeArea()
            
            if !lfm2Manager.isModelInitialized {
                // Show loading screen while model initializes
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.veraLightGreen)
                    
                    Text("Initializing AI Model...")
                        .font(.veraBody())
                        .foregroundColor(.black)
                    
                    Text("This may take a moment on first launch")
                        .font(.veraCaption())
                        .foregroundColor(.black.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ZStack {
                        TransactionsView()
                            .opacity(selectedTab == 0 ? 1 : 0)
                            .environmentObject(csvProcessor)
                        
                        InsightsView()
                            .opacity(selectedTab == 1 ? 1 : 0)
                            .environmentObject(csvProcessor)
                        
                        BudgetView()
                            .opacity(selectedTab == 2 ? 1 : 0)
                            .environmentObject(csvProcessor)
                    }
                    .frame(maxHeight: .infinity)
                    
                    VBottomNav(selectedTab: $selectedTab, tabs: [
                        (icon: "transaction", label: "Transactions"),
                        (icon: "insights", label: "Insights"),
                        (icon: "budget", label: "Budget")
                    ])
                }
            }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}