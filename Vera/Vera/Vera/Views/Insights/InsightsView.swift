import SwiftUI

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

struct InsightsView: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var lfm2Manager = LFM2Manager.shared
    @State private var selectedMonth = Date()
    @State private var cashFlow: CashFlowData?
    @State private var isAnalyzing = false
    
    var body: some View {
        VContainer {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Insights")
                        .font(.veraTitle())
                        .foregroundColor(.black)
                    
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
                                .foregroundColor(.black.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.pie")
                                .font(.custom("Inter", size: 48))
                                .foregroundColor(.black.opacity(0.4))
                            
                            Text("No insights available yet")
                                .font(.veraBody())
                                .foregroundColor(.black.opacity(0.6))
                            
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
        
        Task {
            do {
                // First, process all CSV files (parse, categorize, deduplicate, save)
                print("🔄 Starting full analysis pipeline...")
                let processedTransactions = try await csvProcessor.processAllFiles()
                print("✅ Processed \(processedTransactions.count) transactions")
                
                // Initialize LFM2 if needed
                await lfm2Manager.initialize()
                
                // Get transactions for the selected month from the newly processed data
                let transactions = dataManager.fetchTransactions(for: selectedMonth)
                print("📊 Analyzing \(transactions.count) transactions for selected month")
                
                // Use LFM2Manager to analyze spending with real AI
                let cashFlowData = try await lfm2Manager.analyzeSpending(transactions)
                
                DispatchQueue.main.async {
                    self.cashFlow = cashFlowData
                    self.isAnalyzing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    // Handle error - could show an alert or error state
                    print("Failed to analyze transactions: \(error)")
                }
            }
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
    
    private var isCurrentOrFutureMonth: Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.startOfMonth(for: Date())
        let selectedMonthStart = calendar.startOfMonth(for: selectedMonth)
        return selectedMonthStart >= currentMonth
    }
    
    var body: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.custom("Inter", size: 16).weight(.medium))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            Text(monthFormatter.string(from: selectedMonth))
                .font(.veraBody())
                .foregroundColor(.black)
            
            Spacer()
            
            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .font(.custom("Inter", size: 16).weight(.medium))
                    .foregroundColor(isCurrentOrFutureMonth ? .veraGrey.opacity(0.4) : .veraLightGreen)
            }
            .disabled(isCurrentOrFutureMonth)
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