import SwiftUI

struct PartyMembershipBorder: ViewModifier {
    let isMember: Bool
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    private static let neonGreen = Color(red: 0.224, green: 1.0, blue: 0.078)

    func body(content: Content) -> some View {
        content.overlay {
            if isMember {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Self.neonGreen, lineWidth: lineWidth)
            }
        }
    }
}

extension View {
    func partyMembershipBorder(
        isMember: Bool,
        cornerRadius: CGFloat,
        lineWidth: CGFloat
    ) -> some View {
        modifier(PartyMembershipBorder(isMember: isMember, cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}
