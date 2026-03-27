import SwiftUI

struct PairingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        _PairingViewWrapper(appState: appState)
    }
}

private struct _PairingViewWrapper: View {
    @StateObject private var viewModel: PairingViewModel

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: PairingViewModel(appState: appState))
    }

    var body: some View {
        _PairingViewBody()
            .environmentObject(viewModel)
    }
}

private struct _PairingViewBody: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: PairingViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ConnectionStatusCard(state: viewModel.connectionState)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                switch appState.deviceRole {
                case .sender:   senderSections
                case .receiver: receiverSections
                case .unset:
                    Section {
                        Text("Please select a device role in Settings.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !viewModel.trustedDevices.isEmpty {
                    Section("Trusted Devices") {
                        ForEach(viewModel.trustedDevices) { device in
                            TrustedDeviceRow(device: device) {
                                viewModel.revokeDevice(device)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.connectionState.isConnected {
                        Button("Disconnect", role: .destructive) { viewModel.disconnect() }
                    } else {
                        Button("Refresh") { viewModel.startDiscovery() }
                    }
                }
            }
            .task { viewModel.startDiscovery() }
        }
    }

    @ViewBuilder
    private var senderSections: some View {
        Section("Nearby Devices") {
            NearbyDevicesView(peers: viewModel.discoveredPeers) { peer in
                viewModel.connectTo(peer: peer)
            }
        }
        Section("Mac Relay") {
            HStack {
                Image(systemName: AppConfiguration.backgroundRelayEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(AppConfiguration.backgroundRelayEnabled ? .green : .secondary)
                Text(AppConfiguration.backgroundRelayEnabled && AppConfiguration.backgroundRelayBaseURL != nil ? "Configured" : "Not configured")
                Spacer()
            }
            Text("Mac Relay does not appear in Nearby Devices. It is used directly via URL from Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Manual Pairing") {
            NavigationLink {
                QRCodePairingView(pairingCode: viewModel.pairingCodeFormatted)
            } label: {
                Label("Show QR Code", systemImage: "qrcode")
            }
            NavigationLink {
                PairingCodeView(code: viewModel.pairingCodeFormatted) {
                    viewModel.generatePairingCode()
                }
            } label: {
                Label("Show Pairing Code", systemImage: "number.circle.fill")
            }
        }
    }

    @ViewBuilder
    private var receiverSections: some View {
        Section("Status") {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(.green)
                Text("Advertising to nearby senders").font(.subheadline)
            }
        }
        Section("Pair Using Code") {
            NavigationLink {
                PairingCodeView(code: viewModel.pairingCodeFormatted) {
                    viewModel.generatePairingCode()
                }
            } label: {
                Label("Show Pairing Code", systemImage: "number.circle.fill")
            }
        }
    }
}

// MARK: - ConnectionStatusCard

struct ConnectionStatusCard: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(stateColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: state.systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(stateColor)
                    
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(state.displayTitle).font(.headline)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var stateColor: Color {
        switch state {
        case .connected: return .green
        case .searching: return .blue
        case .pairing:   return .orange
        case .error:     return .red
        default:         return .secondary
        }
    }

    private var statusDetail: String {
        switch state {
        case .idle:                              return "Not searching"
        case .searching:                         return "Looking for nearby devices on your Wi-Fi"
        case .found(let n):                      return "Found \(n) — tap to connect"
        case .pairing:                           return "Completing pairing handshake"
        case .connected(let d):                  return "Paired with \(d.displayName)"
        case .disconnected:                      return "Connection lost"
        case .reconnectingToLastDevice(let name): return "Reconnecting to \(name)"
        case .verifyingTrustedDevice(let name):  return "Verifying \(name)"
        case .cacheExpired:                      return "Session expired, starting discovery"
        case .error(let m):                      return m
        }
    }
}

// MARK: - TrustedDeviceRow

private struct TrustedDeviceRow: View {
    let device: PairedDevice
    let onRevoke: () -> Void
    @State private var showConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.role.systemImage).foregroundStyle(.blue).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName).font(.subheadline.weight(.medium))
                Text("\(device.role.title) • Paired \(device.pairedAt.relativeFormatted)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Revoke", role: .destructive) { showConfirm = true }
        }
        .alert("Revoke Trust", isPresented: $showConfirm) {
            Button("Revoke", role: .destructive) { onRevoke() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove \(device.displayName) from trusted devices?")
        }
    }
}
