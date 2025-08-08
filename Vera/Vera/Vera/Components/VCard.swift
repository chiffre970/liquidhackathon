import SwiftUI

struct VCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content
    var showBorder: Bool = false
    
    init(title: String? = nil,
         subtitle: String? = nil,
         showBorder: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.showBorder = showBorder
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = title {
                        Text(title)
                            .font(.veraSubheading())
                            .foregroundColor(.black)
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.veraCaption())
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
            }
            
            content
        }
        .padding(DesignSystem.padding)
        .background(Color.veraWhite)
        .cornerRadius(DesignSystem.smallCornerRadius)
        .overlay(
            showBorder ?
            RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                .stroke(Color.veraGrey, lineWidth: 1)
            : nil
        )
    }
}