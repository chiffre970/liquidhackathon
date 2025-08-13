//
//  ContentView.swift
//  Vera
//
//  Created by Rueben Heuzenroeder on 8/8/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MeetingView()
                .tabItem {
                    Label("Record", systemImage: "mic.circle")
                }
            
            MeetingListView()
                .tabItem {
                    Label("Meetings", systemImage: "list.bullet")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .preferredColorScheme(.light)
    }
}