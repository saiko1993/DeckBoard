import Foundation
import SwiftUI

// MARK: - Dashboard

struct Dashboard: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var pages: [DashboardPage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "rectangle.grid.2x2",
        colorHex: String = "#007AFF",
        pages: [DashboardPage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.pages = pages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - DashboardPage

struct DashboardPage: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var buttons: [DeskButton]
    var layoutColumns: Int

    init(
        id: UUID = UUID(),
        title: String = "Page",
        buttons: [DeskButton] = [],
        layoutColumns: Int = 3
    ) {
        self.id = id
        self.title = title
        self.buttons = buttons
        self.layoutColumns = layoutColumns
    }
}

// MARK: - DeskButton

struct DeskButton: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var icon: String
    var colorHex: String
    var action: ButtonAction
    var hapticFeedback: Bool
    var position: Int
    var isEnabled: Bool
    var iconURL: String?

    init(
        id: UUID = UUID(),
        title: String,
        icon: String = "star.fill",
        colorHex: String = "#007AFF",
        action: ButtonAction = .none,
        hapticFeedback: Bool = true,
        position: Int = 0,
        isEnabled: Bool = true,
        iconURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.colorHex = colorHex
        self.action = action
        self.hapticFeedback = hapticFeedback
        self.position = position
        self.isEnabled = isEnabled
        self.iconURL = iconURL
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var resolvedIconURL: URL? {
        guard let iconURL, !iconURL.isEmpty else { return nil }
        return URL(string: iconURL)
    }
}