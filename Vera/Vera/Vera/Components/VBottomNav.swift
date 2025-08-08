import SwiftUI

struct VBottomNav: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, label: String)]
    @Namespace private var animationNamespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabButton(
                    icon: tab.icon,
                    label: tab.label,
                    isSelected: selectedTab == index,
                    namespace: animationNamespace,
                    action: {
                        withAnimation(DesignSystem.Animation.spring) {
                            selectedTab = index
                        }
                    }
                )
            }
        }
        .padding(.horizontal, DesignSystem.padding)
        .padding(.vertical, 12)
        .background(Color.veraWhite)
        .overlay(
            Rectangle()
                .fill(Color.veraGrey.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
    }
}

private struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.veraLightGreen)
                            .frame(width: 48, height: 32)
                            .matchedGeometryEffect(id: "tab_indicator", in: namespace)
                    }
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .veraWhite : .veraDarkGreen.opacity(0.5))
                }
                .frame(height: 32)
                
                Text(label)
                    .font(.veraCaption())
                    .foregroundColor(isSelected ? .veraDarkGreen : .veraDarkGreen.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch icon {
        case "transaction":
            return "list.bullet.rectangle"
        case "insights":
            return "chart.pie.fill"
        case "budget":
            return "dollarsign.circle.fill"
        default:
            return "questionmark.circle"
        }
    }
}