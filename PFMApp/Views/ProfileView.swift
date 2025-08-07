import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import your transaction CSV files to get started")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Import CSV") {
                    
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
            .background(Color(.systemGray6))
        }
    }
}