import SwiftUI

// MARK: - SenderView

/// Root sender view. Passes AppState to the inner StateObject-holding wrapper.
struct SenderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        _SenderViewWrapper(appState: appState)
    }
}

// MARK: - _SenderViewWrapper (StateObject holder)

/// Holds the SenderViewModel as a @StateObject. Initialized once from AppState.
private struct _SenderViewWrapper: View {
    @StateObject private var viewModel: SenderViewModel

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: SenderViewModel(appState: appState))
    }

    var body: some View {
        _SenderViewBody()
            .environmentObject(viewModel)
    }
}

// MARK: - _SenderViewBody

private struct _SenderViewBody: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: SenderViewModel
    @State private var showFullscreen: Bool = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(viewModel.activeDashboard?.name ?? "DeskBoard")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbar }
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            if let dashboard = viewModel.activeDashboard,
               let page = viewModel.activePage {
                FullscreenDeckView(dashboard: dashboard, page: page) { button in
                    viewModel.tap(button: button)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if appState.dashboards.isEmpty {
            emptyState
        } else if let dashboard = viewModel.activeDashboard,
                  let page = viewModel.activePage {
            VStack(spacing: 0) {
                ConnectionBanner(state: appState.connectionState)

                if dashboard.pages.count > 1 {
                    PagePickerView(dashboard: dashboard, selectedPage: viewModel.activePage) { page in
                        viewModel.selectPage(page)
                    }
                }

                DashboardGridView(page: page, dashboard: dashboard)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 0)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.secondary)
            Text("No Dashboards")
                .font(.title2.weight(.semibold))
            Text("Create your first dashboard to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Create Dashboard") {
                viewModel.createDashboard(name: "My Dashboard", icon: "rectangle.grid.2x2", colorHex: "#007AFF")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showFullscreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(viewModel.activeDashboard == nil)
        }
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                ForEach(appState.dashboards) { dashboard in
                    Button {
                        viewModel.selectDashboard(dashboard)
                    } label: {
                        Label(dashboard.name, systemImage: dashboard.icon)
                    }
                }
                Divider()
                Button {
                    viewModel.createDashboard(name: "New Dashboard", icon: "rectangle.grid.2x2", colorHex: "#007AFF")
                } label: {
                    Label("New Dashboard", systemImage: "plus")
                }
            } label: {
                Label("Dashboards", systemImage: "rectangle.grid.2x2.fill")
            }
        }
    }
}