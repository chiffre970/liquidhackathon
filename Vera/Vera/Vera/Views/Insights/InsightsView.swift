import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
    @State private var selectedMonth = Date()
    @State private var cashFlow: CashFlowData?
    @State private var isAnalyzing = false
    
    var body: some View {
        VContainer {
            VStack(alignment: .leading, spacing: 24) {
                Text("Insights")
                    .font(.veraTitle())
                    .foregroundColor(.veraDarkGreen)
                
                MonthSelector(selectedMonth: $selectedMonth)
                
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
                            .foregroundColor(.veraDarkGreen.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 50)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 48))
                            .foregroundColor(.veraLightGreen.opacity(0.4))
                        
                        Text("No insights available yet")
                            .font(.veraBody())
                            .foregroundColor(.veraDarkGreen.opacity(0.6))
                        
                        VButton(title: "Analyze Transactions", style: .primary) {
                            analyzeTransactions()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                }
                
                Spacer()
            }
        }
        .onAppear { 
            if !csvProcessor.parsedTransactions.isEmpty {
                analyzeTransactions()
            }
        }
    }
    
    private func analyzeTransactions() {
        isAnalyzing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let mockCategories = [
                CashFlowData.Category(name: "Housing", amount: 2500, percentage: 35),
                CashFlowData.Category(name: "Food", amount: 800, percentage: 11),
                CashFlowData.Category(name: "Transportation", amount: 500, percentage: 7),
                CashFlowData.Category(name: "Entertainment", amount: 400, percentage: 6),
                CashFlowData.Category(name: "Shopping", amount: 600, percentage: 8),
                CashFlowData.Category(name: "Healthcare", amount: 300, percentage: 4),
                CashFlowData.Category(name: "Savings", amount: 2000, percentage: 29)
            ]
            
            self.cashFlow = CashFlowData(
                income: 7100,
                expenses: 5100,
                categories: mockCategories,
                analysis: "Your spending is well-balanced across categories. Housing takes up 35% of your budget, which is within the recommended 30-40% range. You're saving 29% of your income - excellent work! Consider reviewing your shopping and entertainment expenses for potential optimization."
            )
            
            self.isAnalyzing = false
        }
    }
}

struct MonthSelector: View {
    @Binding var selectedMonth: Date
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var body: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.veraLightGreen)
            }
            
            Spacer()
            
            Text(monthFormatter.string(from: selectedMonth))
                .font(.veraBody())
                .foregroundColor(.veraDarkGreen)
            
            Spacer()
            
            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.veraLightGreen)
            }
        }
        .padding()
        .background(Color.veraWhite)
        .cornerRadius(DesignSystem.smallCornerRadius)
    }
    
    private func changeMonth(_ value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
}