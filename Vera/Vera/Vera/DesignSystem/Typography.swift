import SwiftUI

struct Typography {
    static func registerFonts() {
        // Inter font registration would happen here if custom font files are added
        // For now, using "Inter" assumes system availability or fallback to similar font
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
        return .custom("Inter", size: Typography.FontSize.title).weight(Typography.FontWeight.bold)
    }
    
    static func veraHeading() -> Font {
        return .custom("Inter", size: Typography.FontSize.heading).weight(Typography.FontWeight.semibold)
    }
    
    static func veraSubheading() -> Font {
        return .custom("Inter", size: Typography.FontSize.subheading).weight(Typography.FontWeight.semibold)
    }
    
    static func veraBody() -> Font {
        return .custom("Inter", size: Typography.FontSize.body).weight(Typography.FontWeight.regular)
    }
    
    static func veraBodySmall() -> Font {
        return .custom("Inter", size: Typography.FontSize.bodySmall).weight(Typography.FontWeight.regular)
    }
    
    static func veraCaption() -> Font {
        return .custom("Inter", size: Typography.FontSize.caption).weight(Typography.FontWeight.light)
    }
}