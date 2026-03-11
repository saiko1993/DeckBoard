import XCTest
@testable import DeskBoard

final class ButtonActionTests: XCTestCase {

    // MARK: - Display Names

    func testDisplayNames() {
        XCTAssertEqual(ButtonAction.none.displayName,              "No Action")
        XCTAssertEqual(ButtonAction.mediaPlay.displayName,         "Play")
        XCTAssertEqual(ButtonAction.mediaPause.displayName,        "Pause")
        XCTAssertEqual(ButtonAction.mediaPlayPause.displayName,    "Play / Pause")
        XCTAssertEqual(ButtonAction.mediaNext.displayName,         "Next Track")
        XCTAssertEqual(ButtonAction.mediaPrevious.displayName,     "Previous Track")
        XCTAssertEqual(ButtonAction.mediaVolumeUp.displayName,     "Volume Up")
        XCTAssertEqual(ButtonAction.mediaVolumeDown.displayName,   "Volume Down")
        XCTAssertEqual(ButtonAction.presentationNext.displayName,  "Next Slide")
        XCTAssertEqual(ButtonAction.presentationPrevious.displayName, "Previous Slide")
        XCTAssertEqual(ButtonAction.presentationStart.displayName, "Start Presentation")
        XCTAssertEqual(ButtonAction.presentationEnd.displayName,   "End Presentation")
    }

    // MARK: - System Images

    func testSystemImages() {
        XCTAssertEqual(ButtonAction.mediaPlay.systemImage,    "play.fill")
        XCTAssertEqual(ButtonAction.mediaPause.systemImage,   "pause.fill")
        XCTAssertEqual(ButtonAction.mediaNext.systemImage,    "forward.fill")
        XCTAssertEqual(ButtonAction.mediaPrevious.systemImage, "backward.fill")
        XCTAssertEqual(ButtonAction.none.systemImage,         "slash.circle")
    }

    // MARK: - Categories

    func testMediaCategory() {
        XCTAssertEqual(ButtonAction.mediaPlay.category,       .media)
        XCTAssertEqual(ButtonAction.mediaPause.category,      .media)
        XCTAssertEqual(ButtonAction.mediaNext.category,       .media)
        XCTAssertEqual(ButtonAction.mediaPrevious.category,   .media)
        XCTAssertEqual(ButtonAction.mediaVolumeUp.category,   .media)
        XCTAssertEqual(ButtonAction.mediaVolumeDown.category, .media)
    }

    func testPresentationCategory() {
        XCTAssertEqual(ButtonAction.presentationNext.category,     .presentation)
        XCTAssertEqual(ButtonAction.presentationPrevious.category, .presentation)
        XCTAssertEqual(ButtonAction.presentationStart.category,    .presentation)
        XCTAssertEqual(ButtonAction.presentationEnd.category,      .presentation)
    }

    func testGeneralCategory() {
        XCTAssertEqual(ButtonAction.none.category,                  .general)
        XCTAssertEqual(ButtonAction.openURL(url: "").category,      .general)
        XCTAssertEqual(ButtonAction.sendText(text: "").category,    .general)
        XCTAssertEqual(ButtonAction.openDeepLink(url: "").category, .general)
        XCTAssertEqual(ButtonAction.typeText(text: "").category,    .general)
    }

    func testKeyboardCategory() {
        XCTAssertEqual(ButtonAction.keyboardShortcut(modifiers: [], key: "c").category, .keyboard)
    }

    func testMacroCategory() {
        XCTAssertEqual(ButtonAction.macro(actions: []).category, .macro)
    }

    // MARK: - Codable

    func testSimpleActionCodable() throws {
        let actions: [ButtonAction] = [
            .none, .mediaPlay, .mediaPause, .mediaPlayPause,
            .mediaNext, .mediaPrevious, .mediaVolumeUp, .mediaVolumeDown,
            .presentationNext, .presentationPrevious, .presentationStart, .presentationEnd
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for action in actions {
            let data = try encoder.encode(action)
            let decoded = try decoder.decode(ButtonAction.self, from: data)
            XCTAssertEqual(decoded, action, "Round-trip failed for \(action.displayName)")
        }
    }

    func testOpenURLCodable() throws {
        let action = ButtonAction.openURL(url: "https://apple.com")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(action)
        let decoded = try decoder.decode(ButtonAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func testKeyboardShortcutCodable() throws {
        let action = ButtonAction.keyboardShortcut(modifiers: ["cmd", "shift"], key: "k")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(action)
        let decoded = try decoder.decode(ButtonAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    // MARK: - All Simple Actions

    func testAllSimpleActionsNonEmpty() {
        XCTAssertFalse(ButtonAction.allSimpleActions.isEmpty)
    }

    // MARK: - Background Capability

    func testBackgroundSafeActions() {
        XCTAssertFalse(ButtonAction.mediaPlay.requiresForegroundOnIOSReceiver)
        XCTAssertFalse(ButtonAction.mediaVolumeUp.requiresForegroundOnIOSReceiver)
        XCTAssertFalse(ButtonAction.sendText(text: "x").requiresForegroundOnIOSReceiver)
    }

    func testForegroundRequiredActions() {
        XCTAssertTrue(ButtonAction.openURL(url: "https://apple.com").requiresForegroundOnIOSReceiver)
        XCTAssertTrue(ButtonAction.openApp(appID: "youtube").requiresForegroundOnIOSReceiver)
        XCTAssertTrue(ButtonAction.runShortcut(name: "Test").requiresForegroundOnIOSReceiver)
    }

    func testRelayKindsForNewMacActions() {
        XCTAssertEqual(ButtonAction.openApp(appID: "xcode").relayKind, "open_app")
        XCTAssertEqual(ButtonAction.appSwitchNext.relayKind, "app_switch_next")
        XCTAssertEqual(ButtonAction.appSwitchPrevious.relayKind, "app_switch_previous")
        XCTAssertEqual(ButtonAction.closeWindow.relayKind, "close_window")
        XCTAssertEqual(ButtonAction.quitFrontApp.relayKind, "quit_front_app")
        XCTAssertEqual(ButtonAction.minimizeWindow.relayKind, "minimize_window")
        XCTAssertEqual(ButtonAction.missionControl.relayKind, "mission_control")
        XCTAssertEqual(ButtonAction.showDesktop.relayKind, "show_desktop")
        XCTAssertEqual(ButtonAction.moveSpaceLeft.relayKind, "move_space_left")
        XCTAssertEqual(ButtonAction.moveSpaceRight.relayKind, "move_space_right")
    }

    func testDangerousActionClassification() {
        XCTAssertTrue(ButtonAction.forceQuitApp.isDangerousAction)
        XCTAssertTrue(ButtonAction.emptyTrash.isDangerousAction)
        XCTAssertTrue(ButtonAction.sleepDisplay.isDangerousAction)
        XCTAssertTrue(ButtonAction.lockScreen.isDangerousAction)
        XCTAssertTrue(ButtonAction.quitFrontApp.isDangerousAction)
        XCTAssertFalse(ButtonAction.appSwitchNext.isDangerousAction)
    }

    func testMacroForegroundRequirementPropagation() {
        let safeMacro = ButtonAction.macro(actions: [.mediaPlay, .mediaNext])
        XCTAssertFalse(safeMacro.requiresForegroundOnIOSReceiver)

        let mixedMacro = ButtonAction.macro(actions: [.mediaPlay, .openApp(appID: "youtube")])
        XCTAssertTrue(mixedMacro.requiresForegroundOnIOSReceiver)
    }

    // MARK: - PairedDevice

    func testPairedDeviceCodable() throws {
        let device = PairedDevice(
            id: "device-123",
            displayName: "John's iPhone",
            role: .sender,
            pairedAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(device)
        let decoded = try decoder.decode(PairedDevice.self, from: data)
        XCTAssertEqual(decoded.id, device.id)
        XCTAssertEqual(decoded.displayName, device.displayName)
        XCTAssertEqual(decoded.role, .sender)
        XCTAssertTrue(decoded.isTrusted)
    }

    func testDeviceRoleTitles() {
        XCTAssertEqual(DeviceRole.sender.title,   "Sender")
        XCTAssertEqual(DeviceRole.receiver.title, "Receiver")
        XCTAssertEqual(DeviceRole.unset.title,    "Choose Role")
    }

    func testConnectionStateIsConnected() {
        let device = PairedDevice(id: "x", displayName: "X", role: .sender)
        XCTAssertTrue(ConnectionState.connected(to: device).isConnected)
        XCTAssertFalse(ConnectionState.idle.isConnected)
        XCTAssertFalse(ConnectionState.searching.isConnected)
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
    }

    func testConnectionStateIsSearching() {
        XCTAssertTrue(ConnectionState.searching.isSearching)
        XCTAssertFalse(ConnectionState.idle.isSearching)
    }

    func testButtonConfigDefaults() {
        let config = ButtonConfig()
        XCTAssertEqual(config.targetPolicy, .preferReceiver)
        XCTAssertEqual(config.backgroundFallback, .relay)
        XCTAssertEqual(config.retryCount, 1)
        XCTAssertEqual(config.timeoutSeconds, 12)
    }

    func testButtonConfigLegacyDecodeCompatibility() throws {
        let legacy: [String: Any] = [
            "confirmBeforeExecute": true,
            "cooldownSeconds": 1.5
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let decoded = try JSONDecoder().decode(ButtonConfig.self, from: data)
        XCTAssertTrue(decoded.confirmBeforeExecute)
        XCTAssertEqual(decoded.cooldownSeconds, 1.5, accuracy: 0.01)
        XCTAssertEqual(decoded.targetPolicy, .preferReceiver)
        XCTAssertEqual(decoded.backgroundFallback, .relay)
        XCTAssertEqual(decoded.retryCount, 1)
        XCTAssertEqual(decoded.timeoutSeconds, 12)
    }
}
