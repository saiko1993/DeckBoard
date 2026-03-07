import SwiftUI
import Foundation
import UIKit

// MARK: - Color Extensions

extension Color {
    /// Initialize a Color from a hex string (e.g. "#007AFF" or "007AFF").
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8)  & 0xFF) / 255.0
        let b = Double(value         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// Convert a SwiftUI Color to a hex string. Returns nil for non-sRGB colours.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - String Extensions

extension String {
    var isValidURL: Bool {
        guard !isEmpty else { return false }
        return URL(string: self) != nil
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Returns a relative time string (e.g., "2 minutes ago").
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a standard card style.
    func cardStyle(cornerRadius: CGFloat = 16, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }

    /// A conditional modifier helper.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Array Extensions

extension Array where Element: Identifiable {
    /// Replace or insert by id.
    mutating func upsert(_ element: Element) {
        if let idx = firstIndex(where: { $0.id == element.id }) {
            self[idx] = element
        } else {
            append(element)
        }
    }
}