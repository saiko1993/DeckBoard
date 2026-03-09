import Foundation
import Combine
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var deviceName: String = AppConfiguration.deviceName
    @Published var deviceRole: DeviceRole = AppConfiguration.deviceRole
    @Published var appTheme: AppTheme = .system
    @Published var hapticEnabled: Bool = AppConfiguration.hapticEnabled
    @Published var silentReceiver: Bool = AppConfiguration.silentReceiver
    @Published var autoReconnect: Bool = AppConfiguration.autoReconnect
    @Published var pushWakeEnabled: Bool = AppConfiguration.pushWakeEnabled
    @Published var pushGatewayURL: String = AppConfiguration.pushGatewayURL
    @Published var pushGatewayAPIKey: String = AppConfiguration.pushGatewayAPIKey ?? ""
    @Published var trustedDevices: [PairedDevice] = []
    @Published var showRoleChange = false
    @Published var showExportPicker = false
    @Published var exportData: Data?
    @Published var showImportResult = false
    @Published var importResultMessage = ""

    private let appState: AppState
    private let backupService = BackupService.shared
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

    func saveDeviceName() {
        let trimmed = deviceName.trimmed
        guard !trimmed.isEmpty else { return }
        appState.deviceName = trimmed
        appState.reconnect()
    }

    func saveTheme(_ theme: AppTheme) {
        appTheme = theme
        appState.appTheme = theme
    }

    func saveHaptic(_ enabled: Bool) {
        hapticEnabled = enabled
        appState.hapticEnabled = enabled
    }

    func saveSilentReceiver(_ silent: Bool) {
        silentReceiver = silent
        appState.silentReceiver = silent
    }

    func saveAutoReconnect(_ enabled: Bool) {
        autoReconnect = enabled
        appState.setAutoReconnect(enabled)
    }

    func savePushWakeEnabled(_ enabled: Bool) {
        pushWakeEnabled = enabled
        AppConfiguration.pushWakeEnabled = enabled
        syncPushRegistration()
    }

    func savePushGatewayURL() {
        AppConfiguration.pushGatewayURL = pushGatewayURL.trimmed
        pushGatewayURL = AppConfiguration.pushGatewayURL
        syncPushRegistration()
    }

    func savePushGatewayAPIKey() {
        let trimmed = pushGatewayAPIKey.trimmed
        AppConfiguration.pushGatewayAPIKey = trimmed.isEmpty ? nil : trimmed
        pushGatewayAPIKey = AppConfiguration.pushGatewayAPIKey ?? ""
        syncPushRegistration()
    }

    func changeRole(_ role: DeviceRole) {
        appState.setRole(role)
        deviceRole = role
    }

    func exportDashboard(_ dashboard: Dashboard) {
        do {
            exportData = try backupService.exportSingle(dashboard: dashboard, deviceName: deviceName)
            showExportPicker = true
        } catch {
            importResultMessage = "Export failed: \(error.localizedDescription)"
            showImportResult = true
        }
    }

    func exportAllDashboards() {
        do {
            exportData = try backupService.exportAll(
                dashboards: appState.dashboards,
                deviceName: deviceName,
                settings: BackupSettings(
                    hapticEnabled: hapticEnabled,
                    silentReceiver: silentReceiver,
                    defaultColumns: 3,
                    autoReconnect: autoReconnect,
                    timeoutSeconds: 10,
                    retryCount: 1
                )
            )
            showExportPicker = true
        } catch {
            importResultMessage = "Export failed: \(error.localizedDescription)"
            showImportResult = true
        }
    }

    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importResultMessage = "Could not access file"
                showImportResult = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let backup = try backupService.importBackup(from: data)
                for dashboard in backup.dashboards {
                    appState.addDashboard(dashboard)
                }
                importResultMessage = "Imported \(backup.dashboards.count) dashboard(s) from \(backup.deviceName)"
                showImportResult = true
            } catch {
                importResultMessage = "Import failed: \(error.localizedDescription)"
                showImportResult = true
            }

        case .failure(let error):
            importResultMessage = "Could not read file: \(error.localizedDescription)"
            showImportResult = true
        }
    }

    func revokeDevice(_ device: PairedDevice) {
        appState.revokeDevice(id: device.id)
    }

    func resetAllDashboards() {
        DashboardStore.shared.reset()
        appState.dashboards = SampleData.allDashboards
    }

    private func syncPushRegistration() {
        let role = appState.deviceRole
        let name = appState.deviceName
        Task {
            await PushWakeService.shared.registerCurrentDevice(role: role, deviceName: name)
        }
    }
}
