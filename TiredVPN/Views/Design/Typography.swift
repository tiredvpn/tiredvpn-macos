import SwiftUI

extension Font {
    static func splineSans(_ weight: Font.Weight, size: CGFloat) -> Font {
        let name: String
        switch weight {
        case .medium:   name = "SplineSans-Medium"
        case .semibold: name = "SplineSans-SemiBold"
        case .bold:     name = "SplineSans-Bold"
        default:        name = "SplineSans-Regular"
        }
        return .custom(name, size: size)
    }

    static var tvDisplay:  Font { splineSans(.bold,     size: 32) }
    static var tvTitle:    Font { splineSans(.bold,     size: 20) }
    static var tvSubtitle: Font { splineSans(.semibold, size: 17) }
    static var tvBody:     Font { splineSans(.regular,  size: 15) }
    static var tvCaption:  Font { splineSans(.regular,  size: 13) }
    static var tvLabel:    Font { splineSans(.medium,   size: 12) }
}
