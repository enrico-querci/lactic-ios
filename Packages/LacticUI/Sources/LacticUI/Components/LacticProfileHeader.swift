import SwiftUI

/// Who is signed in: initials on the brand colour, then name and email, on
/// the graphite hero surface both apps open their screens with.
public struct LacticProfileHeader: View {
    private let name: String
    private let email: String

    public init(name: String, email: String) {
        self.name = name
        self.email = email
    }

    public var body: some View {
        HStack(spacing: LacticSpacing.lg) {
            Text(verbatim: initials)
                .font(.title2.weight(.bold))
                .foregroundStyle(LacticColor.heroSurface)
                .frame(width: 64, height: 64)
                .background(LacticColor.brand, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(verbatim: name)
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textOnHero)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: email)
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textOnHero.opacity(0.78))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LacticColor.heroSurface,
            in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
        )
    }

    /// Up to two initials; a name Apple or Google never supplied falls back to
    /// the email's first letter rather than an empty circle.
    var initials: String {
        let words = name.split(whereSeparator: \.isWhitespace).prefix(2)
        let letters = words.compactMap(\.first).map(String.init).joined()
        return (letters.isEmpty ? String(email.prefix(1)) : letters).uppercased()
    }
}

#Preview("Profile header") {
    VStack {
        LacticProfileHeader(name: "John Coach", email: "john@example.com")
        LacticProfileHeader(name: "", email: "x7k2@privaterelay.appleid.com")
    }
    .padding()
}
