//
//  ContentView.swift
//  Vera
//
//  Created by Rueben Heuzenroeder on 8/8/2025.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        TabView {
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
            
            InsightsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Insights")
                }
        }
        .tint(.green)
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
