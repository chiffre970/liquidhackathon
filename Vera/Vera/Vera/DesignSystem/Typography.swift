import SwiftUI

struct Typography {
    static func registerFonts() {
    }
    
    enum FontSize {
        static let title: CGFloat = 28
        static let heading: CGFloat = 24
        static let subheading: CGFloat = 20
        static let body: CGFloat = 16
        static let bodySmall: CGFloat = 14
        static let caption: CGFloat = 12
    }
    
    enum FontWeight {
        static let bold = Font.Weight.bold
        static let semibold = Font.Weight.semibold
        static let medium = Font.Weight.medium
        static let regular = Font.Weight.regular
        static let light = Font.Weight.light
    }
}

extension Font {
    static func veraTitle() -> Font {
        return .system(size: Typography.FontSize.title, weight: Typography.FontWeight.bold, design: .default)
    }
    
    static func veraHeading() -> Font {
        return .system(size: Typography.FontSize.heading, weight: Typography.FontWeight.semibold, design: .default)
    }
    
    static func veraSubheading() -> Font {
        return .system(size: Typography.FontSize.subheading, weight: Typography.FontWeight.semibold, design: .default)
    }
    
    static func veraBody() -> Font {
        return .system(size: Typography.FontSize.body, weight: Typography.FontWeight.regular, design: .default)
    }
    
    static func veraBodySmall() -> Font {
        return .system(size: Typography.FontSize.bodySmall, weight: Typography.FontWeight.regular, design: .default)
    }
    
    static func veraCaption() -> Font {
        return .system(size: Typography.FontSize.caption, weight: Typography.FontWeight.light, design: .default)
    }
}