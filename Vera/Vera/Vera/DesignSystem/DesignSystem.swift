import SwiftUI

struct DesignSystem {
    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let tinyCornerRadius: CGFloat = 8
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12
    static let tabBarHeight: CGFloat = 80
    static let containerPadding: CGFloat = 20
    
    // Enhanced radius system with size-based scaling
    struct Radius {
        // Fixed radius values for consistent hierarchy
        static let xs: CGFloat = 4      // Pills, badges, tiny elements
        static let sm: CGFloat = 8      // Buttons, form fields
        static let md: CGFloat = 12     // Cards, panels
        static let lg: CGFloat = 20     // Main containers, modals
        static let xl: CGFloat = 28     // Full-screen containers
        
        // Size-relative radius calculation
        static func relative(to size: CGSize, factor: CGFloat = 0.04) -> CGFloat {
            let minDimension = min(size.width, size.height)
            return max(4, min(28, minDimension * factor))
        }
        
        // Element-specific radius based on common UI patterns
        static func forElement(_ element: RadiusElement) -> CGFloat {
            switch element {
            case .pill: return xs
            case .badge: return xs
            case .button: return sm
            case .input: return sm
            case .card: return md
            case .panel: return md
            case .modal: return lg
            case .container: return lg
            case .fullScreen: return xl
            }
        }
    }
    
    enum RadiusElement {
        case pill, badge, button, input, card, panel, modal, container, fullScreen
    }
}

// SwiftUI extensions for easy radius application
extension View {
    func cornerRadius(_ element: DesignSystem.RadiusElement) -> some View {
        self.cornerRadius(DesignSystem.Radius.forElement(element))
    }
    
    func cornerRadius(relativeTo size: CGSize, factor: CGFloat = 0.04) -> some View {
        self.cornerRadius(DesignSystem.Radius.relative(to: size, factor: factor))
    }
    
    // Convenience methods for common radius sizes
    func radiusXS() -> some View { self.cornerRadius(DesignSystem.Radius.xs) }
    func radiusSM() -> some View { self.cornerRadius(DesignSystem.Radius.sm) }
    func radiusMD() -> some View { self.cornerRadius(DesignSystem.Radius.md) }
    func radiusLG() -> some View { self.cornerRadius(DesignSystem.Radius.lg) }
    func radiusXL() -> some View { self.cornerRadius(DesignSystem.Radius.xl) }
}

extension DesignSystem {
    struct Shadow {
        static let light = (color: Color.black.opacity(0.05), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.1), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let heavy = (color: Color.black.opacity(0.15), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(6))
    }
    
    struct Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
}