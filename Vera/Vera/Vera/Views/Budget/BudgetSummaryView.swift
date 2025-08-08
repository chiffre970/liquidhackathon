import SwiftUI

struct BudgetSummaryView: View {
    let budget: Budget?
    let onNewBudget: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Budget")
                    .font(.veraTitle())
                    .foregroundColor(.veraDarkGreen)
                
                Spacer()
                
                Button("New Budget", action: onNewBudget)
                    .font(.custom("Inter", size: Typography.FontSize.bodySmall).weight(Typography.FontWeight.medium))
                    .foregroundColor(.veraLightGreen)
            }
            
            if let budget = budget {
                BudgetVisualization(budget: budget)
                    .frame(height: 300)
                    .background(Color.veraWhite)
                    .cornerRadius(DesignSystem.smallCornerRadius)
                
                ChangesSection(changes: budget.changes)
                
                TargetCard(monthlyTarget: budget.monthlyTarget, categories: budget.categories)
                
                Spacer()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle")
                        .font(.custom("Inter", size: 48))
                        .foregroundColor(.veraLightGreen.opacity(0.4))
                    
                    Text("No budget created yet")
                        .font(.veraBody())
                        .foregroundColor(.veraDarkGreen.opacity(0.6))
                    
                    VButton(title: "Create Budget", style: .primary) {
                        onNewBudget()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 50)
            }
        }
    }
}

struct BudgetVisualization: View {
    let budget: Budget
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let centerX = size.width / 2
                let incomeHeight: CGFloat = 200
                let incomeWidth: CGFloat = 100
                
                let incomeRect = CGRect(
                    x: centerX - incomeWidth/2,
                    y: 20,
                    width: incomeWidth,
                    height: incomeHeight
                )
                
                context.fill(
                    Path(roundedRect: incomeRect, cornerRadius: 12),
                    with: .color(.veraLightGreen)
                )
                
                // Draw income text
                let incomeAmount = "$\(Int(budget.monthlyTarget))"
                let resolvedIncomeText = context.resolve(Text(incomeAmount))
                let incomeTextRect = CGRect(
                    x: incomeRect.midX - 40,
                    y: incomeRect.midY - 10,
                    width: 80,
                    height: 20
                )
                context.draw(resolvedIncomeText, in: incomeTextRect)
                
                let categoriesStartY = incomeRect.maxY + 30
                let categoryWidth: CGFloat = 70
                let spacing = (size.width - (CGFloat(budget.categories.count) * categoryWidth)) / CGFloat(budget.categories.count + 1)
                
                for (index, category) in budget.categories.enumerated() {
                    let xPos = spacing + (spacing + categoryWidth) * CGFloat(index)
                    let height = (category.percentage / 100) * 120
                    
                    let categoryRect = CGRect(
                        x: xPos,
                        y: categoriesStartY,
                        width: categoryWidth,
                        height: height
                    )
                    
                    let flowPath = Path { p in
                        p.move(to: CGPoint(x: incomeRect.midX, y: incomeRect.maxY))
                        p.addQuadCurve(
                            to: CGPoint(x: categoryRect.midX, y: categoryRect.minY),
                            control: CGPoint(x: (incomeRect.midX + categoryRect.midX) / 2, y: incomeRect.maxY + 20)
                        )
                    }
                    
                    context.stroke(
                        flowPath,
                        with: .color(.veraLightGreen.opacity(0.3)),
                        lineWidth: max(2, category.percentage / 5)
                    )
                    
                    context.fill(
                        Path(roundedRect: categoryRect, cornerRadius: 8),
                        with: .color(.veraDarkGreen.opacity(0.8))
                    )
                    
                    // Draw category text
                    let categoryAmount = "$\(Int(category.amount))"
                    let resolvedCategoryText = context.resolve(Text(categoryAmount))
                    let textRect = CGRect(
                        x: categoryRect.minX,
                        y: categoryRect.midY - 10,
                        width: categoryRect.width,
                        height: 20
                    )
                    context.draw(resolvedCategoryText, in: textRect)
                }
            }
        }
    }
}

struct ChangesSection: View {
    let changes: [String]
    
    var body: some View {
        VCard(title: "Optimizations from Current Spending") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(changes, id: \.self) { change in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.custom("Inter", size: 14))
                            .foregroundColor(.veraLightGreen)
                        
                        Text(change)
                            .font(.veraBodySmall())
                            .foregroundColor(.veraDarkGreen.opacity(0.8))
                    }
                }
            }
        }
    }
}

struct TargetCard: View {
    let monthlyTarget: Double
    let categories: [Budget.CategoryAllocation]
    
    private var savingsAmount: Double {
        categories.first(where: { $0.name == "Savings" })?.amount ?? 0
    }
    
    private var savingsPercentage: Double {
        (savingsAmount / monthlyTarget) * 100
    }
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly Target")
                    .font(.veraCaption())
                    .foregroundColor(.veraDarkGreen.opacity(0.6))
                
                Text("$\(Int(monthlyTarget))")
                    .font(.custom("Inter", size: Typography.FontSize.heading).weight(Typography.FontWeight.bold))
                    .foregroundColor(.veraDarkGreen)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Savings Rate")
                    .font(.veraCaption())
                    .foregroundColor(.veraDarkGreen.opacity(0.6))
                
                Text("\(Int(savingsPercentage))%")
                    .font(.custom("Inter", size: Typography.FontSize.heading).weight(Typography.FontWeight.bold))
                    .foregroundColor(.veraLightGreen)
            }
        }
        .padding()
        .background(Color.veraWhite)
        .cornerRadius(DesignSystem.smallCornerRadius)
    }
}