import SwiftUI

struct VBottomNav: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, label: String)]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabButton(
                    icon: tab.icon,
                    label: tab.label,
                    isSelected: selectedTab == index,
                    action: {
                        selectedTab = index
                    }
                )
            }
        }
        .padding(.horizontal, DesignSystem.padding)
        .padding(.vertical, 12)
        .background(Color.veraWhite)
    }
}

private struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.veraLightGreen)
                        .frame(width: 48, height: 32)
                }
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .veraWhite : .veraDarkGreen.opacity(0.5))
            }
            .frame(height: 32)
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