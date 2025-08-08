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
                    showDivider: shouldShowDivider(for: index),
                    action: {
                        selectedTab = index
                    }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.veraDarkGreen)
        )
        .padding(.horizontal, DesignSystem.padding)
        .padding(.vertical, 12)
        .background(Color.veraWhite)
    }
    
    private func shouldShowDivider(for index: Int) -> Bool {
        // Show divider after this button if:
        // - Not the last button
        // - This button is not selected
        // - Next button is not selected
        return index < tabs.count - 1 && 
               selectedTab != index && 
               selectedTab != index + 1
    }
}

private struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let showDivider: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.veraWhite)
                            .frame(height: 36)
                    }
                    
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .veraLightGreen : .veraWhite.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(PlainButtonStyle())
            
            if showDivider {
                Rectangle()
                    .fill(Color.veraWhite.opacity(0.3))
                    .frame(width: 1, height: 20)
            }
        }
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