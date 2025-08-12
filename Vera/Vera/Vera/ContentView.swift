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
    
    var body: some View {
        ZStack {
            Color.veraWhite.ignoresSafeArea()
            
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

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}