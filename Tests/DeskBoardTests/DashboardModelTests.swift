import XCTest
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
        let dashboard = Dashboard(name: "Blue", colorHex: "#007AFF")
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