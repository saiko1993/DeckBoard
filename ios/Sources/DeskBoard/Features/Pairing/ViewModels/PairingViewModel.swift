import Foundation
import MultipeerConnectivity
import Combine

@MainActor
final class PairingViewModel: ObservableObject {

    @Published var connectionState: ConnectionState = .idle
    @Published var discoveredPeers: [DiscoveredPeer] = []
    @Published var trustedDevices: [PairedDevice] = []
    @Published var pairingCode: String = ""
    @Published var showQRCode = false
    @Published var showPairingCode = false

    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        bind()
        generatePairingCode()
    }

    // MARK: - Binding

    private func bind() {
        appState.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        appState.$discoveredPeers
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoveredPeers)

        appState.$trustedDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$trustedDevices)
    }

    // MARK: - Pairing Code

    func generatePairingCode() {
        pairingCode = String(format: "%06d", Int.random(in: 100_000...999_999))
    }

    var pairingCodeFormatted: String {
        let code = pairingCode
        guard code.count == 6 else { return code }
        return "\(code.prefix(3))-\(code.suffix(3))"
    }

    // MARK: - Discovery

    func startDiscovery() {
        appState.ensureConnectionActive()
    }

    func stopDiscovery() {
        appState.disconnect()
    }

    // MARK: - Connect

    func connectTo(peer: DiscoveredPeer) {
        PeerSession.shared.invite(peer: peer)
    }

    // MARK: - Trusted Device Management

    func revokeDevice(_ device: PairedDevice) {
        appState.revokeDevice(id: device.id)
    }

    func disconnect() {
        appState.disconnect()
    }
}
