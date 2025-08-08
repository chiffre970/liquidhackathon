import SwiftUI

enum VButtonStyle {
    case primary
    case secondary
    case ghost
}

struct VButton: View {
    let title: String
    let style: VButtonStyle
    let action: () -> Void
    var isFullWidth: Bool = false
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .veraDarkGreen
        case .secondary:
            return .veraLightGreen
        case .ghost:
            return .clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .veraWhite
        case .secondary:
            return .veraDarkGreen
        case .ghost:
            return .veraLightGreen
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Typography.FontSize.body, weight: Typography.FontWeight.semibold))
                .foregroundColor(foregroundColor)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(backgroundColor)
                .cornerRadius(DesignSystem.smallCornerRadius)
                .overlay(
                    style == .ghost ?
                    RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                        .stroke(foregroundColor, lineWidth: 1)
                    : nil
                )
        }
    }
}