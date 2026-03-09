import Foundation
import Combine

@MainActor
final class SenderViewModel: ObservableObject {

    @Published var dashboards: [Dashboard] = []
    @Published var activeDashboard: Dashboard?
    @Published var activePage: DashboardPage?
    @Published var connectionState: ConnectionState = .idle
    @Published var showAddDashboard = false
    @Published var showEditDashboard = false
    @Published var showButtonEditor = false
    @Published var editingButton: DeskButton?
    @Published var editingPage: DashboardPage?
    @Published var buttonExecutionStates: [UUID: ButtonExecutionState] = [:]

    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        bindAppState()
    }

    // MARK: - Bindings

    private func bindAppState() {
        appState.$dashboards
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dashboards in
                guard let self else { return }
                self.dashboards = dashboards
                if self.activeDashboard == nil || !dashboards.contains(where: { $0.id == self.activeDashboard?.id }) {
                    self.activeDashboard = dashboards.first
                    self.activePage = dashboards.first?.pages.first
                } else if let id = self.activeDashboard?.id,
                          let updated = dashboards.first(where: { $0.id == id }) {
                    self.activeDashboard = updated
                    if self.activePage == nil || !updated.pages.contains(where: { $0.id == self.activePage?.id }) {
                        self.activePage = updated.pages.first
                    }
                }
            }
            .store(in: &cancellables)

        appState.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        appState.$senderButtonStates
            .receive(on: DispatchQueue.main)
            .assign(to: &$buttonExecutionStates)
    }

    // MARK: - Dashboard Selection

    func selectDashboard(_ dashboard: Dashboard) {
        activeDashboard = dashboard
        activePage = dashboard.pages.first
        appState.activeDashboardID = dashboard.id
    }

    func selectPage(_ page: DashboardPage) {
        activePage = page
    }

    // MARK: - Button Action

    func tap(button: DeskButton) {
        guard button.isEnabled else { return }
        appState.send(action: button.action, button: button)
    }

    func stateFor(_ buttonID: UUID) -> ButtonExecutionState {
        buttonExecutionStates[buttonID] ?? .idle
    }

    // MARK: - Dashboard CRUD

    func createDashboard(name: String, icon: String, colorHex: String) {
        let page = DashboardPage(title: "Main", buttons: [])
        let dashboard = Dashboard(name: name, icon: icon, colorHex: colorHex, pages: [page])
        appState.addDashboard(dashboard)
        selectDashboard(dashboard)
    }

    func deleteDashboard(_ dashboard: Dashboard) {
        appState.deleteDashboard(id: dashboard.id)
    }

    func duplicateDashboard(_ dashboard: Dashboard) {
        var copy = dashboard
        copy.id = UUID()
        copy.name = "\(dashboard.name) Copy"
        appState.addDashboard(copy)
    }

    // MARK: - Page CRUD

    func addPage(to dashboard: Dashboard) {
        var updated = dashboard
        let page = DashboardPage(title: "Page \(updated.pages.count + 1)")
        updated.pages.append(page)
        appState.updateDashboard(updated)
        activeDashboard = updated
        activePage = page
    }

    func deletePage(_ page: DashboardPage, from dashboard: Dashboard) {
        var updated = dashboard
        updated.pages.removeAll { $0.id == page.id }
        appState.updateDashboard(updated)
        activeDashboard = updated
        activePage = updated.pages.first
    }

    func duplicatePage(_ page: DashboardPage, in dashboard: Dashboard) {
        var updated = dashboard
        var copy = page
        copy.id = UUID()
        copy.title = "\(page.title) Copy"
        copy.buttons = page.buttons.map { btn in
            var b = btn
            b.id = UUID()
            return b
        }
        updated.pages.append(copy)
        appState.updateDashboard(updated)
        activeDashboard = updated
        activePage = copy
    }

    func setColumns(_ count: Int, for page: DashboardPage, in dashboard: Dashboard) {
        var updated = dashboard
        guard let pageIdx = updated.pages.firstIndex(where: { $0.id == page.id }) else { return }
        updated.pages[pageIdx].layoutColumns = count
        appState.updateDashboard(updated)
        activeDashboard = updated
        activePage = updated.pages[pageIdx]
    }

    // MARK: - Button CRUD

    func addButton(_ button: DeskButton, to page: DashboardPage, in dashboard: Dashboard) {
        var updated = dashboard
        guard let pageIdx = updated.pages.firstIndex(where: { $0.id == page.id }) else { return }
        var updatedPage = updated.pages[pageIdx]
        var newButton = button
        newButton.position = updatedPage.buttons.count
        updatedPage.buttons.append(newButton)
        updated.pages[pageIdx] = updatedPage
        appState.updateDashboard(updated)
        activeDashboard = updated
        activePage = updated.pages[pageIdx]
    }

    func updateButton(_ button: DeskButton, in page: DashboardPage, dashboard: Dashboard) {
        var updated = dashboard
        guard let pageIdx = updated.pages.firstIndex(where: { $0.id == page.id }) else { return }
        updated.pages[pageIdx].buttons.upsert(button)
        appState.updateDashboard(updated)
        activeDashboard = updated
        activePage = updated.pages[pageIdx]
    }

    func deleteButton(_ button: DeskButton, from page: DashboardPage, in dashboard: Dashboard) {
        var updated = dashboard
        guard let pageIdx = updated.pages.firstIndex(where: { $0.id == page.id }) else { return }
        updated.pages[pageIdx].buttons.removeAll { $0.id == button.id }
        appState.updateDashboard(updated)
        activeDashboard = updated
        activePage = updated.pages[pageIdx]
    }

    func moveButtons(in page: DashboardPage, dashboard: Dashboard, from source: IndexSet, to destination: Int) {
        var updated = dashboard
        guard let pageIdx = updated.pages.firstIndex(where: { $0.id == page.id }) else { return }
        updated.pages[pageIdx].buttons.move(fromOffsets: source, toOffset: destination)
        appState.updateDashboard(updated)
        activeDashboard = updated
        activePage = updated.pages[pageIdx]
    }
}
