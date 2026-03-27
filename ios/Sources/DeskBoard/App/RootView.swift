import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isOnboardingDone {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(appState.appTheme.colorScheme)
        .sheet(item: Binding(
            get: { appState.incomingPairingRequest },
            set: { _ in }
        )) { request in
            PairingApprovalSheet(request: request)
        }
    }
}

// MARK: - Pairing Approval Sheet

private struct PairingApprovalSheet: View {
    let request: IncomingPairingRequest
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.blue)
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text("Pairing Request")
                        .font(.title2.weight(.bold))
                    Text("**\(request.deviceName)** wants to connect as a sender.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        appState.acceptPairing()
                        dismiss()
                    } label: {
                        Label("Accept", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        appState.rejectPairing()
                        dismiss()
                    } label: {
                        Text("Reject")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - MainTabView

private struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            Group {
                switch appState.deviceRole {
                case .sender:
                    SenderView()
                case .receiver:
                    ReceiverView()
                case .unset:
                    OnboardingView()
                }
            }
            .tabItem { Label("Home", systemImage: homeTabIcon) }

            PairingView()
                .tabItem { Label("Connect", systemImage: "antenna.radiowaves.left.and.right") }
                .badge(connectTabBadge)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }

    private var homeTabIcon: String {
        switch appState.deviceRole {
        case .sender:   return "rectangle.grid.2x2.fill"
        case .receiver: return "antenna.radiowaves.left.and.right"
        case .unset:    return "house.fill"
        }
    }

    private var connectTabBadge: String? {
        if appState.connectionState.isConnected {
            return nil
        }
        if appState.isDirectRelayReadyForSender {
            return nil
        }
        return "!"
    }
}
