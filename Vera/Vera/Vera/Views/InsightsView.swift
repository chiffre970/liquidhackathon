import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
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
                    InsightsContentView(csvProcessor: csvProcessor)
                case .budget:
                    BudgetContentView(csvProcessor: csvProcessor)
                }
                
                Spacer()
            }
            .navigationTitle("Analysis")
            .background(Color(.systemGray6))
        }
    }
}

struct InsightsContentView: View {
    @ObservedObject var csvProcessor: CSVProcessor
    
    var body: some View {
        VStack(spacing: 20) {
            if csvProcessor.importedFiles.isEmpty {
                Text("Go to the profile page and upload your CSV files to get started!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                VStack(spacing: 15) {
                    Text("Ready to analyze your transactions!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("You have \(csvProcessor.importedFiles.count) CSV file\(csvProcessor.importedFiles.count == 1 ? "" : "s") uploaded.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button("Analyze Transactions") {
                        // TODO: Trigger LFM2 analysis
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
            }
        }
    }
}

struct BudgetContentView: View {
    @ObservedObject var csvProcessor: CSVProcessor
    
    var body: some View {
        VStack(spacing: 20) {
            if csvProcessor.importedFiles.isEmpty {
                Text("Go to the profile page and upload your CSV files to get started!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                VStack(spacing: 15) {
                    Text("Ready to create your budget!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("You have \(csvProcessor.importedFiles.count) CSV file\(csvProcessor.importedFiles.count == 1 ? "" : "s") uploaded.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button("Generate Budget Recommendations") {
                        // TODO: Trigger LFM2 budget analysis
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
            }
        }
    }
}