import SwiftUI

struct SankeyDiagram: View {
    let data: CashFlowData
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let incomeRect = CGRect(x: 20, y: size.height/2 - 40, width: 80, height: 80)
                
                context.fill(
                    Path(roundedRect: incomeRect, cornerRadius: 8),
                    with: .color(.veraLightGreen)
                )
                
                let incomeText = Text("Income\n$\(Int(data.income))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                context.draw(incomeText, at: CGPoint(x: incomeRect.midX, y: incomeRect.midY))
                
                let categoryHeight = (size.height - 40) / CGFloat(data.categories.count)
                let rightX = size.width - 100
                
                for (index, category) in data.categories.enumerated() {
                    let yPos = 20 + categoryHeight * CGFloat(index)
                    let categoryRect = CGRect(x: rightX, y: yPos, width: 80, height: categoryHeight * 0.8)
                    
                    let flowWidth = max(2, (category.percentage / 100) * 60)
                    
                    let path = Path { p in
                        let startX = incomeRect.maxX
                        let startY = incomeRect.midY
                        let endX = categoryRect.minX
                        let endY = categoryRect.midY
                        
                        p.move(to: CGPoint(x: startX, y: startY - flowWidth/2))
                        
                        let controlPoint1 = CGPoint(x: startX + 50, y: startY)
                        let controlPoint2 = CGPoint(x: endX - 50, y: endY)
                        
                        p.addCurve(
                            to: CGPoint(x: endX, y: endY - flowWidth/2),
                            control1: controlPoint1,
                            control2: controlPoint2
                        )
                        
                        p.addLine(to: CGPoint(x: endX, y: endY + flowWidth/2))
                        
                        p.addCurve(
                            to: CGPoint(x: startX, y: startY + flowWidth/2),
                            control1: controlPoint2,
                            control2: controlPoint1
                        )
                        
                        p.closeSubpath()
                    }
                    
                    context.fill(
                        path,
                        with: .color(.veraLightGreen.opacity(0.3 + (category.percentage / 200)))
                    )
                    
                    context.fill(
                        Path(roundedRect: categoryRect, cornerRadius: 6),
                        with: .color(.veraDarkGreen.opacity(0.8))
                    )
                    
                    let categoryText = Text("\(category.name)\n\(Int(category.percentage))%")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    context.draw(categoryText, at: CGPoint(x: categoryRect.midX, y: categoryRect.midY))
                }
            }
        }
    }
}