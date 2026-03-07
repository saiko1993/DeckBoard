import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var deviceName: String = AppConfiguration.deviceName
    @Published var deviceRole: DeviceRole = AppConfiguration.deviceRole
    @Published var appTheme: AppTheme = .system
    @Published var hapticEnabled: Bool = AppConfiguration.hapticEnabled
    @Published var silentReceiver: Bool = AppConfiguration.silentReceiver
    @Published var trustedDevices: [PairedDevice] = []
    @Published var showRoleChange = false
    @Published var showExportPicker = false
    @Published var exportData: Data?

    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        bind()
    }

    private func bind() {
        appState.$trustedDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$trustedDevices)

        appState.$appTheme
            .receive(on: DispatchQueue.main)
            .assign(to: &$appTheme)
    }

    // MARK: - Save

    func saveDeviceName() {
        let trimmed = deviceName.trimmed
        guard !trimmed.isEmpty else { return }
        appState.deviceName = trimmed
    }

    func saveTheme(_ theme: AppTheme) {
        appState.appTheme = theme
    }

    func saveHaptic(_ enabled: Bool) {
        appState.hapticEnabled = enabled
    }

    func saveSilentReceiver(_ silent: Bool) {
        appState.silentReceiver = silent
    }

    func changeRole(_ role: DeviceRole) {
        appState.setRole(role)
        deviceRole = role
    }

    // MARK: - Dashboard Export

    func exportDashboard(_ dashboard: Dashboard) {
        exportData = DashboardStore.shared.export(dashboard)
        showExportPicker = true
    }

    // MARK: - Device Revocation

    func revokeDevice(_ device: PairedDevice) {
        appState.revokeDevice(id: device.id)
    }

    // MARK: - Reset

    func resetAllDashboards() {
        DashboardStore.shared.reset()
        appState.dashboards = SampleData.allDashboards
    }
}