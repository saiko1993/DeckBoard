import Foundation
import SwiftUI

// MARK: - Dashboard

nonisolated struct Dashboard: Codable, Identifiable, Hashable, Sendable {
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

// MARK: - Dashboard Layout

nonisolated enum DashboardLayoutMode: String, Codable, Hashable, Sendable, CaseIterable {
    case grid
    case freeform

    var title: String {
        switch self {
        case .grid:
            return "Grid"
        case .freeform:
            return "Freeform"
        }
    }
}

// MARK: - Knobs

nonisolated enum DeckKnobPlacement: String, Codable, Hashable, Sendable, CaseIterable {
    case leading
    case trailing
    case center
}

nonisolated enum DeckKnobHapticStyle: String, Codable, Hashable, Sendable, CaseIterable {
    case off
    case selection
    case light
    case medium
    case heavy
}

nonisolated struct DeckKnobConfig: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var label: String
    var size: Double
    var stepThreshold: Double
    var hapticStyle: DeckKnobHapticStyle
    var clockwiseAction: ButtonAction
    var counterClockwiseAction: ButtonAction
    var pressAction: ButtonAction?
    var longPressAction: ButtonAction?
    var placement: DeckKnobPlacement
    var isVisible: Bool

    init(
        id: UUID = UUID(),
        label: String,
        size: Double = 92,
        stepThreshold: Double = 14,
        hapticStyle: DeckKnobHapticStyle = .selection,
        clockwiseAction: ButtonAction,
        counterClockwiseAction: ButtonAction,
        pressAction: ButtonAction? = nil,
        longPressAction: ButtonAction? = nil,
        placement: DeckKnobPlacement,
        isVisible: Bool = true
    ) {
        self.id = id
        self.label = label
        self.size = min(max(size, 56), 220)
        self.stepThreshold = min(max(stepThreshold, 6), 36)
        self.hapticStyle = hapticStyle
        self.clockwiseAction = clockwiseAction
        self.counterClockwiseAction = counterClockwiseAction
        self.pressAction = pressAction
        self.longPressAction = longPressAction
        self.placement = placement
        self.isVisible = isVisible
    }
}

// MARK: - DashboardPage

nonisolated struct DashboardPage: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var buttons: [DeskButton]
    var layoutColumns: Int
    var layoutMode: DashboardLayoutMode
    var knobs: [DeckKnobConfig]

    init(
        id: UUID = UUID(),
        title: String = "Page",
        buttons: [DeskButton] = [],
        layoutColumns: Int = 3,
        layoutMode: DashboardLayoutMode = .grid,
        knobs: [DeckKnobConfig] = DashboardPage.defaultKnobs
    ) {
        self.id = id
        self.title = title
        self.buttons = buttons
        self.layoutColumns = layoutColumns
        self.layoutMode = layoutMode
        self.knobs = knobs
    }

    static var defaultKnobs: [DeckKnobConfig] {
        [
            DeckKnobConfig(
                label: "VOL",
                size: 96,
                stepThreshold: 14,
                hapticStyle: .selection,
                clockwiseAction: .mediaVolumeUp,
                counterClockwiseAction: .mediaVolumeDown,
                pressAction: .mediaMute,
                placement: .leading
            ),
            DeckKnobConfig(
                label: "NAV",
                size: 96,
                stepThreshold: 14,
                hapticStyle: .selection,
                clockwiseAction: .mediaNext,
                counterClockwiseAction: .mediaPrevious,
                placement: .trailing
            )
        ]
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case buttons
        case layoutColumns
        case layoutMode
        case knobs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Page"
        buttons = try container.decodeIfPresent([DeskButton].self, forKey: .buttons) ?? []
        layoutColumns = try container.decodeIfPresent(Int.self, forKey: .layoutColumns) ?? 3
        layoutMode = try container.decodeIfPresent(DashboardLayoutMode.self, forKey: .layoutMode) ?? .grid
        knobs = try container.decodeIfPresent([DeckKnobConfig].self, forKey: .knobs) ?? Self.defaultKnobs
    }
}

// MARK: - Freeform Button Model

nonisolated enum DeskButtonShape: String, Codable, Hashable, Sendable, CaseIterable {
    case roundedRectangle
    case capsule
    case circle

    var title: String {
        switch self {
        case .roundedRectangle:
            return "Rounded"
        case .capsule:
            return "Capsule"
        case .circle:
            return "Circle"
        }
    }
}

nonisolated enum DeskButtonSizePreset: String, Codable, Hashable, Sendable, CaseIterable {
    case small
    case medium
    case large
    case extraLarge
    case custom

    var title: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .extraLarge:
            return "XL"
        case .custom:
            return "Custom"
        }
    }
}

nonisolated struct DeckButtonFrame: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var zIndex: Double

    init(
        x: Double = 16,
        y: Double = 16,
        width: Double = 96,
        height: Double = 96,
        zIndex: Double = 0
    ) {
        self.x = x
        self.y = y
        self.width = max(width, 60)
        self.height = max(height, 60)
        self.zIndex = zIndex
    }
}

// MARK: - DeskButton

nonisolated struct DeskButton: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var subtitle: String?
    var icon: String
    var colorHex: String
    var action: ButtonAction
    var hapticFeedback: Bool
    var position: Int
    var isEnabled: Bool
    var iconURL: String?
    var buttonFrame: DeckButtonFrame?
    var buttonShape: DeskButtonShape
    var sizePreset: DeskButtonSizePreset
    var dragLocked: Bool
    var config: ButtonConfig

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        icon: String = "star.fill",
        colorHex: String = "#007AFF",
        action: ButtonAction = .none,
        hapticFeedback: Bool = true,
        position: Int = 0,
        isEnabled: Bool = true,
        iconURL: String? = nil,
        buttonFrame: DeckButtonFrame? = nil,
        buttonShape: DeskButtonShape = .roundedRectangle,
        sizePreset: DeskButtonSizePreset = .medium,
        dragLocked: Bool = false,
        config: ButtonConfig = ButtonConfig()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colorHex = colorHex
        self.action = action
        self.hapticFeedback = hapticFeedback
        self.position = position
        self.isEnabled = isEnabled
        self.iconURL = iconURL
        self.buttonFrame = buttonFrame
        self.buttonShape = buttonShape
        self.sizePreset = sizePreset
        self.dragLocked = dragLocked
        self.config = config
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var resolvedIconURL: URL? {
        guard let iconURL, !iconURL.isEmpty else { return nil }
        return URL(string: iconURL)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case icon
        case colorHex
        case action
        case hapticFeedback
        case position
        case isEnabled
        case iconURL
        case buttonFrame
        case buttonShape
        case sizePreset
        case dragLocked
        case config
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Button"
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "star.fill"
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#007AFF"
        action = try container.decodeIfPresent(ButtonAction.self, forKey: .action) ?? .none
        hapticFeedback = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedback) ?? true
        position = try container.decodeIfPresent(Int.self, forKey: .position) ?? 0
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
        buttonFrame = try container.decodeIfPresent(DeckButtonFrame.self, forKey: .buttonFrame)
        buttonShape = try container.decodeIfPresent(DeskButtonShape.self, forKey: .buttonShape) ?? .roundedRectangle
        sizePreset = try container.decodeIfPresent(DeskButtonSizePreset.self, forKey: .sizePreset) ?? .medium
        dragLocked = try container.decodeIfPresent(Bool.self, forKey: .dragLocked) ?? false
        config = try container.decodeIfPresent(ButtonConfig.self, forKey: .config) ?? ButtonConfig()
    }
}
