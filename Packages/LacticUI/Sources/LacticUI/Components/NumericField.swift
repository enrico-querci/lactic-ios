import SwiftUI

/// A number entry field for a weight or a rep count.
///
/// Commits on blur rather than on every keystroke, matching the web: typing
/// "72.5" passes through "7" and "72", and sending each of those would issue
/// three writes and briefly persist two wrong values. It also skips the write
/// entirely when the parsed value is unchanged.
///
/// The field is `.decimalPad` for weights and `.numberPad` for reps, because
/// neither should offer a keyboard that can produce text the parser rejects.
public struct NumericField: View {
    public enum Kind: Sendable {
        case weight
        case reps

        var suffix: String {
            switch self {
            case .weight: "kg"
            case .reps: "reps"
            }
        }
    }

    private let kind: Kind
    private let value: Decimal
    private let onCommit: (Decimal) -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    public init(kind: Kind, value: Decimal, onCommit: @escaping (Decimal) -> Void) {
        self.kind = kind
        self.value = value
        self.onCommit = onCommit
        _text = State(initialValue: Self.format(value))
    }

    public var body: some View {
        HStack(spacing: LacticSpacing.xs) {
            TextField("", text: $text)
                .font(.lacticNumeric)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .frame(minHeight: LacticSize.minimumHitTarget)
            #if os(iOS)
                .keyboardType(kind == .weight ? .decimalPad : .numberPad)
            #endif
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        commit()
                    }
                }

            Text(kind.suffix)
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textSecondary)
        }
        .padding(.horizontal, LacticSpacing.sm)
        .background(LacticColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(isFocused ? LacticColor.accent : LacticColor.border, lineWidth: 1)
        }
        // The value can change underneath the field — an outbox reconciling a
        // server response, or a session being rehydrated — but not while it is
        // being edited, which would fight the user mid-keystroke.
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            text = Self.format(newValue)
        }
    }

    private func commit() {
        guard let parsed = Self.parse(text) else {
            text = Self.format(value) // Unparseable: put the old value back.
            return
        }
        guard parsed != value else { return }
        onCommit(parsed)
    }

    /// Parses with a fixed locale, not the user's. The keypad can emit either
    /// separator depending on region, and the wire format is always a dot.
    static func parse(_ text: String) -> Decimal? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Trims a trailing `.0`: a weight reads as `70`, not `70.00`, but `72.5`
    /// keeps its half.
    static func format(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(Locale(identifier: "en_US_POSIX")))
    }
}

#Preview("Numeric fields") {
    VStack(spacing: LacticSpacing.md) {
        NumericField(kind: .weight, value: Decimal(string: "72.5") ?? 0) { _ in }
        NumericField(kind: .reps, value: 8) { _ in }
    }
    .padding()
    .background(LacticColor.surface)
}
