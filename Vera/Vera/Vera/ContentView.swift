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
    
    var body: some View {
        ZStack {
            Color.veraWhite.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ZStack {
                    TransactionsView()
                        .opacity(selectedTab == 0 ? 1 : 0)
                    
                    InsightsView()
                        .opacity(selectedTab == 1 ? 1 : 0)
                    
                    BudgetView()
                        .opacity(selectedTab == 2 ? 1 : 0)
                }
                .frame(maxHeight: .infinity)
                .animation(nil, value: selectedTab)
                
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