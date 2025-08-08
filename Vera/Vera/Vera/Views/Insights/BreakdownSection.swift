import SwiftUI

struct BreakdownSection: View {
    let cashFlow: CashFlowData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.veraSubheading())
                .foregroundColor(.veraDarkGreen)
            
            if let cashFlow = cashFlow {
                VStack(alignment: .leading, spacing: 16) {
                    if let analysis = cashFlow.analysis {
                        Text(analysis)
                            .font(.veraBodySmall())
                            .foregroundColor(.veraDarkGreen.opacity(0.8))
                            .lineSpacing(4)
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(cashFlow.categories, id: \.name) { category in
                            HStack {
                                Circle()
                                    .fill(Color.veraLightGreen.opacity(0.3 + (category.percentage / 200)))
                                    .frame(width: 8, height: 8)
                                
                                Text(category.name)
                                    .font(.veraBodySmall())
                                    .foregroundColor(.veraDarkGreen)
                                
                                Spacer()
                                
                                Text("$\(Int(category.amount))")
                                    .font(.system(size: Typography.FontSize.bodySmall, weight: Typography.FontWeight.medium))
                                    .foregroundColor(.veraDarkGreen)
                                
                                Text("\(Int(category.percentage))%")
                                    .font(.veraCaption())
                                    .foregroundColor(.veraDarkGreen.opacity(0.6))
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                    .padding()
                    .background(Color.veraGrey.opacity(0.3))
                    .cornerRadius(DesignSystem.tinyCornerRadius)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Income")
                                .font(.veraCaption())
                                .foregroundColor(.veraDarkGreen.opacity(0.6))
                            Text("$\(Int(cashFlow.income))")
                                .font(.system(size: Typography.FontSize.subheading, weight: Typography.FontWeight.semibold))
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Expenses")
                                .font(.veraCaption())
                                .foregroundColor(.veraDarkGreen.opacity(0.6))
                            Text("$\(Int(cashFlow.expenses))")
                                .font(.system(size: Typography.FontSize.subheading, weight: Typography.FontWeight.semibold))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Net")
                                .font(.veraCaption())
                                .foregroundColor(.veraDarkGreen.opacity(0.6))
                            Text("$\(Int(cashFlow.income - cashFlow.expenses))")
                                .font(.system(size: Typography.FontSize.subheading, weight: Typography.FontWeight.semibold))
                                .foregroundColor(cashFlow.income > cashFlow.expenses ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color.veraWhite)
                    .cornerRadius(DesignSystem.smallCornerRadius)
                }
            } else {
                Text("Analyzing your spending patterns...")
                    .font(.veraBodySmall())
                    .foregroundColor(.veraGrey)
                    .italic()
            }
        }
        .padding()
        .background(Color.veraWhite)
        .cornerRadius(DesignSystem.smallCornerRadius)
    }
}