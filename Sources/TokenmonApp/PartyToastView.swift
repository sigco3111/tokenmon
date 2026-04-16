import SwiftUI

struct PartyToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

struct PartyToastOverlay: ViewModifier {
    @Binding var toast: PartyToast?
    var displayDuration: TimeInterval = 3

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast {
                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.78))
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: UInt64(displayDuration * 1_000_000_000))
                        if self.toast?.id == toast.id {
                            withAnimation { self.toast = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: toast)
    }
}

extension View {
    func partyToast(_ toast: Binding<PartyToast?>) -> some View {
        modifier(PartyToastOverlay(toast: toast))
    }
}
