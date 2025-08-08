import SwiftUI

struct VContainer<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    var backgroundColor: Color = .veraGrey
    var cornerRadius: CGFloat = 20
    
    init(padding: CGFloat = 20, 
         backgroundColor: Color = .veraGrey,
         cornerRadius: CGFloat = 20,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .padding(.horizontal, DesignSystem.padding)
    }
}