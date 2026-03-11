import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var testURL: String = ""
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var isCheckingReadiness = false
    @State private var readiness: ConnectionReadiness = .baseline
    @State private var isCheckingRelayCapabilities = false
    @State private var relayCapabilitiesResult: String?
    @State private var relayCapabilities: [String] = []
    @State private var relayUsableCapabilities: [String] = []
    @State private var relayBlockedCapabilities: [String] = []

    var body: some View {
        List {
            Section("Connection Status") {
                InfoRow(label: "State", value: appState.connectionState.displayTitle)
                InfoRow(label: "Device Role", value: appState.deviceRole.title)
                InfoRow(label: "Device Name", value: appState.deviceName)
                InfoRow(label: "Trusted Devices", value: "\(appState.trustedDevices.count)")
            }

            Section("Connection Readiness") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(readiness.overallStatus.title)
                        .foregroundStyle(readinessColor)
                }
                InfoRow(label: "APNs Token", value: readiness.apnsTokenReady ? "Ready" : "Missing")
                InfoRow(label: "Wake Gateway", value: readiness.gatewayConfigured ? "Configured" : "Missing")
                InfoRow(label: "Gateway Reachability", value: readiness.gatewayReachable ? "Reachable" : "Unavailable")
                InfoRow(label: "Relay", value: readiness.relayConfigured ? "Configured" : "Missing")
                InfoRow(label: "APNs Topic Match", value: topicMatchValue)
                InfoRow(label: "Blocking Error", value: readiness.blockingErrorCode ?? "None")

                Button {
                    runReadinessCheck()
                } label: {
                    HStack {
                        Text("Run Readiness Check")
                        Spacer()
                        if isCheckingReadiness {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isCheckingReadiness)

                if !readiness.notes.isEmpty {
                    ForEach(readiness.notes, id: \.self) { note in
                        Text("• \(note)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if readiness.apnsTopicMatchesBundle == false {
                    Text("Fix guide: set APNS_BUNDLE_ID in your push gateway to match this app bundle identifier exactly.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Data") {
                InfoRow(label: "Dashboards", value: "\(appState.dashboards.count)")
                InfoRow(
                    label: "Total Buttons",
                    value: "\(appState.dashboards.flatMap(\.pages).flatMap(\.buttons).count)"
                )
                InfoRow(
                    label: "Total Pages",
                    value: "\(appState.dashboards.flatMap(\.pages).count)"
                )
            }

            Section("Connection Test") {
                TextField("http://192.168.1.100:8080", text: $testURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    testConnection()
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(testURL.trimmed.isEmpty || isTesting)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("✓") ? .green : .red)
                }
            }

            Section("App Info") {
                InfoRow(label: "Version", value: AppConfiguration.appVersion)
                InfoRow(label: "Build", value: AppConfiguration.buildNumber)
                InfoRow(label: "iOS", value: UIDevice.current.systemVersion)
                InfoRow(label: "Model", value: UIDevice.current.model)
            }

            Section("Push Wake") {
                InfoRow(label: "Enabled", value: AppConfiguration.pushWakeEnabled ? "Yes" : "No")
                InfoRow(label: "Gateway", value: AppConfiguration.pushGatewayURL.trimmed.isEmpty ? "Not set" : "Configured")
                InfoRow(label: "APNs Token", value: shortToken(AppConfiguration.pushToken))
                InfoRow(label: "Device UUID", value: PeerSession.stableDeviceUUID)
            }

            Section("Background Commands") {
                InfoRow(label: "Queued Foreground Actions", value: "\(appState.deferredCommandCount)")
                InfoRow(label: "Mac Relay Enabled", value: AppConfiguration.backgroundRelayEnabled ? "Yes" : "No")
                InfoRow(label: "Mac Relay URL", value: AppConfiguration.backgroundRelayURL.trimmed.isEmpty ? "Not set" : "Configured")

                Button {
                    checkRelayCapabilities()
                } label: {
                    HStack {
                        Text("Check Relay Capabilities")
                        Spacer()
                        if isCheckingRelayCapabilities {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                }
                .disabled(!AppConfiguration.backgroundRelayEnabled || AppConfiguration.backgroundRelayBaseURL == nil || isCheckingRelayCapabilities)

                if let relayCapabilitiesResult {
                    Text(relayCapabilitiesResult)
                        .font(.caption)
                        .foregroundStyle(relayCapabilitiesResult.contains("✓") ? .green : .secondary)
                }

                if !relayCapabilities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(relayCapabilities, id: \.self) { capability in
                                Text(capability)
                                    .font(.caption2.monospaced())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !relayUsableCapabilities.isEmpty || !relayBlockedCapabilities.isEmpty {
                    InfoRow(label: "Usable", value: "\(relayUsableCapabilities.count)")
                    InfoRow(label: "Unmapped", value: "\(relayBlockedCapabilities.count)")
                }

                if !relayBlockedCapabilities.isEmpty {
                    Text("These relay capabilities are not yet mapped in the button builder:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(relayBlockedCapabilities, id: \.self) { capability in
                                Text(capability)
                                    .font(.caption2.monospaced())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if appState.deviceRole == .sender {
                Section("Sender Execution") {
                    InfoRow(label: "Running Buttons", value: "\(runningButtonCount)")
                    InfoRow(label: "Queued Buttons", value: "\(queuedButtonCount)")
                    InfoRow(label: "Failed Buttons", value: "\(failedButtonCount)")
                }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            runReadinessCheck()
        }
    }

    private var readinessColor: Color {
        switch readiness.overallStatus {
        case .ready:
            return .green
        case .partial:
            return .orange
        case .misconfigured:
            return .red
        }
    }

    private var topicMatchValue: String {
        guard let topicMatch = readiness.apnsTopicMatchesBundle else { return "Unknown" }
        return topicMatch ? "Matched" : "Mismatch"
    }

    private func runReadinessCheck() {
        isCheckingReadiness = true
        Task {
            let snapshot = await ConnectionReadinessService.shared.evaluate()
            await MainActor.run {
                readiness = snapshot
                isCheckingReadiness = false
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            let reachable = await HTTPActionService.shared.testConnection(urlString: testURL.trimmed)
            testResult = reachable ? "✓ Reachable" : "✗ Unreachable"
            isTesting = false
        }
    }

    private func shortToken(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "Not registered" }
        if value.count <= 16 { return value }
        return "\(value.prefix(8))...\(value.suffix(8))"
    }

    private var runningButtonCount: Int {
        appState.senderButtonStates.values.filter {
            if case .running = $0 { return true }
            return false
        }.count
    }

    private var queuedButtonCount: Int {
        appState.senderButtonStates.values.filter {
            if case .queued = $0 { return true }
            return false
        }.count
    }

    private var failedButtonCount: Int {
        appState.senderButtonStates.values.filter {
            if case .failed = $0 { return true }
            return false
        }.count
    }

    private func checkRelayCapabilities() {
        guard let baseURL = AppConfiguration.backgroundRelayBaseURL else {
            relayCapabilitiesResult = "Relay URL is not configured"
            return
        }

        isCheckingRelayCapabilities = true
        relayCapabilitiesResult = nil
        relayCapabilities = []
        relayUsableCapabilities = []
        relayBlockedCapabilities = []

        Task {
            defer { isCheckingRelayCapabilities = false }

            var request = URLRequest(url: baseURL.appendingPathComponent("v1/capabilities"))
            request.httpMethod = "GET"
            if let key = AppConfiguration.backgroundRelayAPIKey?.trimmed, !key.isEmpty {
                request.setValue(key, forHTTPHeaderField: "x-deskboard-key")
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    relayCapabilitiesResult = "Relay response is invalid"
                    return
                }
                guard (200...299).contains(http.statusCode) else {
                    relayCapabilitiesResult = "Relay check failed (HTTP \(http.statusCode))"
                    return
                }

                let payload = try JSONDecoder().decode(RelayCapabilitiesResponse.self, from: data)
                relayCapabilitiesResult = "✓ Relay online, \(payload.capabilities.count) capabilities"
                relayCapabilities = payload.capabilities.sorted()
                relayUsableCapabilities = payload.capabilities.filter(Self.knownActionCapabilitySet.contains).sorted()
                relayBlockedCapabilities = payload.capabilities.filter { !Self.knownActionCapabilitySet.contains($0) }.sorted()
            } catch {
                relayCapabilitiesResult = "Relay check failed: \(error.localizedDescription)"
            }
        }
    }

    private static let knownActionCapabilitySet: Set<String> = [
        "open_url", "open_deep_link", "send_text", "type_text",
        "open_app", "run_shortcut", "run_script", "keyboard_shortcut",
        "toggle_dark_mode", "screenshot", "screen_record", "sleep_display",
        "lock_screen", "open_terminal", "force_quit_app", "empty_trash",
        "toggle_dnd", "presentation_next", "presentation_previous",
        "presentation_start", "presentation_end",
        "media_play", "media_pause", "media_play_pause", "media_next",
        "media_previous", "media_volume_up", "media_volume_down",
        "media_mute", "app_switch_next", "app_switch_previous",
        "close_window", "quit_front_app", "minimize_window",
        "mission_control", "show_desktop", "move_space_left", "move_space_right",
        "macro"
    ]
}

private struct RelayCapabilitiesResponse: Codable {
    let ok: Bool
    let service: String?
    let protocolVersion: Int?
    let serviceVersion: String?
    let capabilities: [String]
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }
}
