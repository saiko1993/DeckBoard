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
                    Picker("Theme", selection: $viewModel.appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .onChange(of: viewModel.appTheme) { _, newValue in viewModel.saveTheme(newValue) }
                }

                Section("Behaviour") {
                    Toggle(isOn: $viewModel.hapticEnabled) {
                        Label("Haptic Feedback", systemImage: "hand.tap.fill")
                    }
                    .onChange(of: viewModel.hapticEnabled) { _, newValue in viewModel.saveHaptic(newValue) }

                    if appState.deviceRole == .receiver {
                        Toggle(isOn: $viewModel.silentReceiver) {
                            Label("Silent Mode", systemImage: "bell.slash.fill")
                        }
                        .onChange(of: viewModel.silentReceiver) { _, newValue in viewModel.saveSilentReceiver(newValue) }
                    }
                }

                Section("Dashboards") {
                    ForEach(appState.dashboards) { dashboard in
                        HStack {
                            Label(dashboard.name, systemImage: dashboard.icon)
                            Spacer()
                            Button {
                                viewModel.exportDashboard(dashboard)
                            } label: {
                                Image(systemName: "square.and.arrow.up").foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
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
        }
    }
}

// MARK: - Supporting Types

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

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ConnectionBanner (shared UI component)

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
        case .searching: return .blue.opacity(0.1)
        case .error:     return .red.opacity(0.1)
        default:         return .secondary.opacity(0.08)
        }
    }

    private var bannerForeground: Color {
        switch state {
        case .searching: return .blue
        case .error:     return .red
        default:         return .secondary
        }
    }
}