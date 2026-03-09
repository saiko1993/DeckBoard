import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        _SettingsViewWrapper(appState: appState)
    }
}

private struct _SettingsViewWrapper: View {
    @StateObject private var viewModel: SettingsViewModel

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(appState: appState))
    }

    var body: some View {
        _SettingsViewBody().environmentObject(viewModel)
    }
}

private struct _SettingsViewBody: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showImportPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Device") {
                    HStack {
                        Label("Device Name", systemImage: "iphone")
                        Spacer()
                        TextField("Device Name", text: $viewModel.deviceName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .onSubmit { viewModel.saveDeviceName() }
                    }
                    HStack {
                        Label("Role", systemImage: appState.deviceRole.systemImage)
                        Spacer()
                        Text(appState.deviceRole.title).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.showRoleChange = true }
                }

                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { viewModel.appTheme },
                        set: { viewModel.saveTheme($0) }
                    )) {
                        ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }

                Section("Behaviour") {
                    Toggle(isOn: Binding(
                        get: { viewModel.hapticEnabled },
                        set: { viewModel.saveHaptic($0) }
                    )) {
                        Label("Haptic Feedback", systemImage: "hand.tap.fill")
                    }

                    if appState.deviceRole == .receiver {
                        Toggle(isOn: Binding(
                            get: { viewModel.silentReceiver },
                            set: { viewModel.saveSilentReceiver($0) }
                        )) {
                            Label("Silent Mode", systemImage: "bell.slash.fill")
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.autoReconnect },
                        set: { viewModel.saveAutoReconnect($0) }
                    )) {
                        Label("Auto Reconnect", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Section("Background Wake") {
                    Toggle(isOn: Binding(
                        get: { viewModel.pushWakeEnabled },
                        set: { viewModel.savePushWakeEnabled($0) }
                    )) {
                        Label("Enable Silent Push Wake", systemImage: "bell.badge")
                    }

                    HStack {
                        Label("Gateway URL", systemImage: "network")
                        Spacer()
                        TextField("https://your-worker.workers.dev", text: $viewModel.pushGatewayURL)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.secondary)
                            .onSubmit { viewModel.savePushGatewayURL() }
                    }

                    HStack {
                        Label("Gateway API Key", systemImage: "key.horizontal")
                        Spacer()
                        SecureField("Optional", text: $viewModel.pushGatewayAPIKey)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.secondary)
                            .onSubmit { viewModel.savePushGatewayAPIKey() }
                    }

                    Button {
                        viewModel.savePushGatewayURL()
                        viewModel.savePushGatewayAPIKey()
                    } label: {
                        Label("Save Wake Settings", systemImage: "square.and.arrow.down")
                    }
                }

                Section("Mac Receiver Relay") {
                    Toggle(isOn: Binding(
                        get: { viewModel.backgroundRelayEnabled },
                        set: { viewModel.saveBackgroundRelayEnabled($0) }
                    )) {
                        Label("Forward blocked background actions", systemImage: "desktopcomputer.and.arrow.down")
                    }

                    HStack {
                        Label("Relay URL", systemImage: "network")
                        Spacer()
                        TextField("http://192.168.1.20:7788", text: $viewModel.backgroundRelayURL)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.secondary)
                            .onSubmit { viewModel.saveBackgroundRelayURL() }
                    }

                    HStack {
                        Label("Relay API Key", systemImage: "key.horizontal")
                        Spacer()
                        SecureField("Optional", text: $viewModel.backgroundRelayAPIKey)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.secondary)
                            .onSubmit { viewModel.saveBackgroundRelayAPIKey() }
                    }

                    Button {
                        viewModel.saveBackgroundRelayURL()
                        viewModel.saveBackgroundRelayAPIKey()
                    } label: {
                        Label("Save Relay Settings", systemImage: "square.and.arrow.down")
                    }
                }

                Section("Dashboards") {
                    ForEach(appState.dashboards) { dashboard in
                        HStack {
                            Label(dashboard.name, systemImage: dashboard.icon)
                            Spacer()
                            Text("\(dashboard.pages.count) pages")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Button {
                                viewModel.exportDashboard(dashboard)
                            } label: {
                                Image(systemName: "square.and.arrow.up").foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        viewModel.exportAllDashboards()
                    } label: {
                        Label("Export All Dashboards", systemImage: "square.and.arrow.up.on.square")
                    }

                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Dashboards", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        viewModel.resetAllDashboards()
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    }
                }

                if !viewModel.trustedDevices.isEmpty {
                    Section("Trusted Devices") {
                        ForEach(viewModel.trustedDevices) { device in
                            HStack {
                                Image(systemName: device.role.systemImage)
                                    .foregroundStyle(.secondary).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName).font(.subheadline)
                                    Text(device.role.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Revoke", role: .destructive) { viewModel.revokeDevice(device) }
                            }
                        }
                    }
                }

                Section("Debug") {
                    Toggle(isOn: Binding(
                        get: { viewModel.experimentalBackgroundKeepAliveEnabled },
                        set: { viewModel.saveExperimentalBackgroundKeepAlive($0) }
                    )) {
                        Label("Experimental Background Keep-Alive", systemImage: "waveform")
                    }

                    NavigationLink {
                        ExecutionLogView()
                    } label: {
                        Label("Execution History", systemImage: "list.bullet.rectangle")
                    }

                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("Diagnostics", systemImage: "wrench.and.screwdriver")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConfiguration.appVersion) (\(AppConfiguration.buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showRoleChange) {
                RoleChangeSheet { role in viewModel.changeRole(role) }
            }
            .sheet(isPresented: $viewModel.showExportPicker) {
                if let data = viewModel.exportData { ShareSheet(items: [data]) }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleImport(result)
            }
            .alert("Import Result", isPresented: $viewModel.showImportResult) {
                Button("OK") {}
            } message: {
                Text(viewModel.importResultMessage)
            }
        }
    }
}

private struct RoleChangeSheet: View {
    let onSelect: (DeviceRole) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach([DeviceRole.sender, DeviceRole.receiver], id: \.self) { role in
                    Button {
                        onSelect(role)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: role.systemImage).foregroundStyle(.blue).frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(role.title).font(.headline).foregroundStyle(.primary)
                                Text(role.description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Change Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ConnectionBanner: View {
    let state: ConnectionState

    var body: some View {
        if !state.isConnected {
            HStack(spacing: 8) {
                Image(systemName: state.systemImage).font(.caption.weight(.semibold))
                Text(state.displayTitle).font(.caption.weight(.medium))
                Spacer()
            }
            .foregroundStyle(bannerForeground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(bannerBackground)
        }
    }

    private var bannerBackground: Color {
        switch state {
        case .searching:                 return .blue.opacity(0.1)
        case .reconnectingToLastDevice:  return .orange.opacity(0.1)
        case .verifyingTrustedDevice:    return .purple.opacity(0.1)
        case .cacheExpired:              return .yellow.opacity(0.1)
        case .error:                     return .red.opacity(0.1)
        default:                         return .secondary.opacity(0.08)
        }
    }

    private var bannerForeground: Color {
        switch state {
        case .searching:                 return .blue
        case .reconnectingToLastDevice:  return .orange
        case .verifyingTrustedDevice:    return .purple
        case .cacheExpired:              return .yellow
        case .error:                     return .red
        default:                         return .secondary
        }
    }
}
