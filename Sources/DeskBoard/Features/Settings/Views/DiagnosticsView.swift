import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var testURL: String = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        List {
            Section("Connection Status") {
                InfoRow(label: "State", value: appState.connectionState.displayTitle)
                InfoRow(label: "Device Role", value: appState.deviceRole.title)
                InfoRow(label: "Device Name", value: appState.deviceName)
                InfoRow(label: "Trusted Devices", value: "\(appState.trustedDevices.count)")
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
