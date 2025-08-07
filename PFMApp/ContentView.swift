import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                }
                .tag(0)
            
            InsightsView()
                .tabItem {
                    Image(systemName: "chart.bar.doc.horizontal")
                }
                .tag(1)
        }
        .accentColor(.green)
    }
}