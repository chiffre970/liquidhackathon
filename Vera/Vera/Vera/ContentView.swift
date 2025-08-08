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
                Group {
                    switch selectedTab {
                    case 0:
                        TransactionsView()
                    case 1:
                        InsightsView()
                    case 2:
                        BudgetView()
                    default:
                        TransactionsView()
                    }
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