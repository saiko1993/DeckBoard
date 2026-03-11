import XCTest
import SwiftUI
@testable import DeskBoard

final class DashboardModelTests: XCTestCase {

    // MARK: - Dashboard

    func testDashboardDefaultValues() {
        let dashboard = Dashboard(name: "Test")
        XCTAssertFalse(dashboard.id.uuidString.isEmpty)
        XCTAssertEqual(dashboard.name, "Test")
        XCTAssertEqual(dashboard.icon, "rectangle.grid.2x2")
        XCTAssertEqual(dashboard.colorHex, "#007AFF")
        XCTAssertTrue(dashboard.pages.isEmpty)
    }

    func testDashboardColorParsing() {
        _ = Dashboard(name: "Blue", colorHex: "#007AFF")
        // Color should be non-nil
        let color = Color(hex: "#007AFF")
        XCTAssertNotNil(color)
    }

    // MARK: - DashboardPage

    func testDashboardPageDefaults() {
        let page = DashboardPage()
        XCTAssertEqual(page.title, "Page")
        XCTAssertTrue(page.buttons.isEmpty)
        XCTAssertEqual(page.layoutColumns, 3)
        XCTAssertEqual(page.layoutMode, .grid)
        XCTAssertFalse(page.knobs.isEmpty)
    }

    func testDashboardPageLegacyDecodeCompatibility() throws {
        let legacyPage: [String: Any] = [
            "id": UUID().uuidString,
            "title": "Legacy",
            "buttons": [],
            "layoutColumns": 4
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyPage)
        let decoded = try JSONDecoder().decode(DashboardPage.self, from: data)
        XCTAssertEqual(decoded.title, "Legacy")
        XCTAssertEqual(decoded.layoutColumns, 4)
        XCTAssertEqual(decoded.layoutMode, .grid)
        XCTAssertFalse(decoded.knobs.isEmpty)
    }

    func testDashboardPageFreeformRoundTrip() throws {
        let frame = DeckButtonFrame(x: 40, y: 55, width: 180, height: 130, zIndex: 4)
        let button = DeskButton(
            title: "Free Button",
            icon: "star.fill",
            action: .typeText(text: "hello"),
            buttonFrame: frame,
            buttonShape: .capsule,
            sizePreset: .custom,
            dragLocked: true
        )
        let knob = DeckKnobConfig(
            label: "NAV",
            size: 170,
            stepThreshold: 12,
            hapticStyle: .light,
            clockwiseAction: .appSwitchNext,
            counterClockwiseAction: .appSwitchPrevious,
            pressAction: .missionControl,
            longPressAction: .showDesktop,
            placement: .trailing
        )
        let page = DashboardPage(
            title: "Freeform",
            buttons: [button],
            layoutColumns: 3,
            layoutMode: .freeform,
            knobs: [knob]
        )

        let data = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(DashboardPage.self, from: data)
        let decodedButton = try XCTUnwrap(decoded.buttons.first)
        let decodedFrame = try XCTUnwrap(decodedButton.buttonFrame)
        let decodedKnob = try XCTUnwrap(decoded.knobs.first)
        XCTAssertEqual(decoded.layoutMode, .freeform)
        XCTAssertEqual(decodedFrame.width, 180, accuracy: 0.01)
        XCTAssertEqual(decodedButton.buttonShape, .capsule)
        XCTAssertEqual(decodedButton.sizePreset, .custom)
        XCTAssertEqual(decodedButton.dragLocked, true)
        XCTAssertEqual(decodedKnob.label, "NAV")
        XCTAssertEqual(decodedKnob.size, 170, accuracy: 0.01)
    }

    // MARK: - DeskButton

    func testDeskButtonDefaults() {
        let button = DeskButton(title: "Play", icon: "play.fill", action: .mediaPlay)
        XCTAssertEqual(button.title, "Play")
        XCTAssertEqual(button.icon, "play.fill")
        XCTAssertTrue(button.hapticFeedback)
        XCTAssertTrue(button.isEnabled)
    }

    func testDeskButtonCodable() throws {
        let button = DeskButton(
            title: "Next Track",
            icon: "forward.fill",
            colorHex: "#34C759",
            action: .mediaNext
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(button)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeskButton.self, from: data)
        XCTAssertEqual(decoded.id, button.id)
        XCTAssertEqual(decoded.title, button.title)
        XCTAssertEqual(decoded.colorHex, button.colorHex)
    }

    func testDeskButtonLegacyDecodeCompatibility() throws {
        let legacy: [String: Any] = [
            "id": UUID().uuidString,
            "title": "Legacy",
            "icon": "star.fill",
            "colorHex": "#007AFF",
            "position": 0
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let decoded = try JSONDecoder().decode(DeskButton.self, from: data)
        XCTAssertNil(decoded.buttonFrame)
        XCTAssertEqual(decoded.buttonShape, .roundedRectangle)
        XCTAssertEqual(decoded.sizePreset, .medium)
        XCTAssertFalse(decoded.dragLocked)
    }

    // MARK: - Color Extension

    func testColorHexInitValid() {
        XCTAssertNotNil(Color(hex: "#007AFF"))
        XCTAssertNotNil(Color(hex: "007AFF"))
        XCTAssertNotNil(Color(hex: "#34C759"))
    }

    func testColorHexInitInvalid() {
        XCTAssertNil(Color(hex: "#GGGGGG"))
        XCTAssertNil(Color(hex: "short"))
        XCTAssertNil(Color(hex: ""))
    }

    // MARK: - SampleData

    func testSampleDataNotEmpty() {
        XCTAssertFalse(SampleData.allDashboards.isEmpty)
        XCTAssertTrue(SampleData.allDashboards.count >= 3)
    }

    func testSampleDashboardsHavePages() {
        for dashboard in SampleData.allDashboards {
            XCTAssertFalse(dashboard.pages.isEmpty, "\(dashboard.name) should have pages")
            for page in dashboard.pages {
                XCTAssertFalse(page.buttons.isEmpty, "\(dashboard.name)/\(page.title) should have buttons")
            }
        }
    }
}
