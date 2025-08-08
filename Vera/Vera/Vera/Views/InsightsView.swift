import SwiftUI

struct InsightsView: View {
    @State private var selectedView: InsightType = .insights
    
    enum InsightType: String, CaseIterable {
        case insights = "Insights"
        case budget = "Budget"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("View Type", selection: $selectedView) {
                    ForEach(InsightType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                switch selectedView {
                case .insights:
                    InsightsContentView()
                case .budget:
                    BudgetContentView()
                }
                
                Spacer()
            }
            .navigationTitle("Analysis")
            .background(Color(.systemGray6))
        }
    }
}

struct InsightsContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Go to the profile page and add your transactions to get started!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct BudgetContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Go to the profile page and add your transactions to get started!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}