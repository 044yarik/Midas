import SwiftUI

enum Theme {
    static let bg = Color.black
    static let card = Color(white: 0.11)
    static let cardSoft = Color(white: 0.17)
    static let accent = Color(hex: "E3B04B")   // жёлтый, как на скринах
    static let green = Color(hex: "34C759")
    static let secondary = Color(white: 0.55)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct AccentButton: View {
    var title: String
    var icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Theme.accent, in: Capsule())
        }
    }
}

struct ScanFAB: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "viewfinder")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.black.opacity(0.85))
                .frame(width: 80, height: 80)
                .background(Theme.accent, in: Circle())
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        }
    }
}
