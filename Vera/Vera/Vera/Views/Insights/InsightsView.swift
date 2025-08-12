import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
    @StateObject private var dataManager = DataManager.shared
    @State private var cashFlow: CashFlowData?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VContainer {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Insights")
                        .font(.veraTitle())
                        .foregroundColor(.black)
                    
                    if let cashFlow = cashFlow {
                        SankeyDiagram(data: cashFlow)
                            .frame(height: 300)
                            .background(Color.veraWhite)
                            .cornerRadius(DesignSystem.smallCornerRadius)
                        
                        BreakdownSection(cashFlow: cashFlow)
                    } else if isAnalyzing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .veraLightGreen))
                                .scaleEffect(1.2)
                            
                            Text("Analyzing your spending patterns...")
                                .font(.veraBodySmall())
                                .foregroundColor(.black.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: errorMessage != nil ? "exclamationmark.triangle" : "chart.pie")
                                .font(.custom("Inter", size: 48))
                                .foregroundColor(errorMessage != nil ? .red.opacity(0.6) : .black.opacity(0.4))
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(.veraBody())
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            } else {
                                Text("No insights available yet")
                                    .font(.veraBody())
                                    .foregroundColor(.black.opacity(0.6))
                            }
                            
                            VButton(title: "Analyze Transactions", style: .primary) {
                                analyzeTransactions()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    }
                }
            }
        }
        .onAppear { 
            if !csvProcessor.parsedTransactions.isEmpty {
                analyzeTransactions()
            }
        }
    }
    
    @MainActor
    private func analyzeTransactions() {
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                // First, process all CSV files (parse, categorize, deduplicate, save)
                print("🔄 Starting full analysis pipeline...")
                let processedTransactions = try await csvProcessor.processAllFiles()
                print("✅ Processed \(processedTransactions.count) transactions")
                
                // Get ALL transactions (no month filtering)
                let transactions = dataManager.transactions
                print("📊 Analyzing \(transactions.count) total transactions")
                
                // Calculate cash flow data based on CSV categories
                let cashFlowData = calculateCashFlow(from: transactions)
                
                DispatchQueue.main.async {
                    self.cashFlow = cashFlowData
                    self.isAnalyzing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.errorMessage = error.localizedDescription
                    print("Failed to analyze transactions: \(error)")
                }
            }
        }
    }
    
    private func calculateCashFlow(from transactions: [Transaction]) -> CashFlowData {
        let income = transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expenses = abs(transactions.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount })
        
        var categoryTotals: [String: Double] = [:]
        
        // Aggregate by category from CSV
        for transaction in transactions.filter({ $0.amount < 0 }) {
            let category = transaction.category ?? "Uncategorized"
            categoryTotals[category, default: 0] += abs(transaction.amount)
        }
        
        // Sort categories by amount and create category objects
        let categories = categoryTotals.map { key, value in
            CashFlowData.Category(
                name: key,
                amount: value,
                percentage: expenses > 0 ? (value / expenses) * 100 : 0
            )
        }.sorted { $0.amount > $1.amount }
        
        // Generate simple analysis text
        let topCategory = categories.first?.name ?? "Unknown"
        let topPercentage = categories.first?.percentage ?? 0
        let analysis = """
        Your spending is distributed across \(categories.count) categories.
        The largest expense category is \(topCategory), accounting for \(String(format: "%.1f", topPercentage))% of total spending.
        Total income: $\(String(format: "%.2f", income))
        Total expenses: $\(String(format: "%.2f", expenses))
        Net: $\(String(format: "%.2f", income - expenses))
        """
        
        return CashFlowData(
            income: income,
            expenses: expenses,
            categories: categories,
            analysis: analysis
        )
    }
}