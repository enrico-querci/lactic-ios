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
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(LacticColor.textPrimary)
                .accessibilityLabel(kind == .weight ? Text("Weight", bundle: .main) : Text("Reps", bundle: .main))
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .frame(minHeight: 52)
            #if os(iOS)
                .keyboardType(kind == .weight ? .decimalPad : .numberPad)
            #endif
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        commit()
                    }
                }

            Group {
                if kind == .weight {
                    Text(verbatim: "kg")
                } else {
                    Text("reps", bundle: .main)
                }
            }
            .font(.lacticCaption)
            .foregroundStyle(LacticColor.textSecondary)
        }
        .padding(.horizontal, LacticSpacing.sm)
        .background(isFocused ? LacticColor.surfaceElevated : LacticColor.surface)
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
        #if os(iOS)
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { isFocused = false } label: { Text("Done", bundle: .main) }
                }
            }
        }
        #endif
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
