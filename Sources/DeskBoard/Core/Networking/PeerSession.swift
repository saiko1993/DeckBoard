import Foundation
@preconcurrency import MultipeerConnectivity

// MARK: - IncomingPairingRequest

struct IncomingPairingRequest: @unchecked Sendable, Identifiable {
    var id: String { peerID.displayName }
    let peerID: MCPeerID
    let deviceName: String
    let deviceRole: String
}

// MARK: - DiscoveredPeer

struct DiscoveredPeer: Identifiable, @unchecked Sendable {
    let id: String              // displayName
    let peerID: MCPeerID
    let role: DeviceRole?

    var displayName: String { peerID.displayName }
}

// MARK: - PeerSession

/// Manages MultipeerConnectivity session for local peer discovery and communication.
///
/// - Note: Marked `@unchecked Sendable` because MC delegate callbacks arrive on
///   arbitrary threads; all Published mutations are dispatched to the main queue.
final class PeerSession: NSObject, @unchecked Sendable, ObservableObject {

    static let shared = PeerSession()

    // MARK: - Published State

    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var discoveredPeers: [DiscoveredPeer] = []
    @Published private(set) var connectedPeerNames: [String] = []
    @Published private(set) var receivedCommand: CommandMessage?
    @Published private(set) var incomingPairingRequest: IncomingPairingRequest?

    // MARK: - Private Properties

    private let serviceType = "deskboard-v1"
    private let encoder = CommandEncoder()

    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?
    private var currentRole: DeviceRole = .unset

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Call once before using; sets up MC peer and session.
    func configure(deviceName: String, role: DeviceRole) {
        currentRole = role
        let pid = MCPeerID(displayName: deviceName)
        peerID = pid
        let sess = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .required)
        sess.delegate = self
        session = sess
    }

    // MARK: - Advertising (Receiver)

    func startAdvertising() {
        guard let pid = peerID else { return }
        let info: [String: String] = [
            "role": currentRole.rawValue,
            "version": AppConfiguration.appVersion
        ]
        let adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: info, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
        publishOnMain { self.connectionState = .searching }
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Browsing (Sender)

    func startBrowsing() {
        guard let pid = peerID else { return }
        let brw = MCNearbyServiceBrowser(peer: pid, serviceType: serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw
        publishOnMain { self.connectionState = .searching }
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        publishOnMain { self.discoveredPeers = [] }
    }

    func stopAll() {
        stopAdvertising()
        stopBrowsing()
        session?.disconnect()
        publishOnMain {
            self.connectionState = .idle
            self.connectedPeerNames = []
            self.discoveredPeers = []
        }
    }

    // MARK: - Connection

    func invite(peer: DiscoveredPeer) {
        guard let session else { return }
        browser?.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 30)
        publishOnMain { self.connectionState = .pairing }
    }

    func acceptPairing() {
        guard let handler = pendingInvitationHandler, let session else { return }
        handler(true, session)
        pendingInvitationHandler = nil
        publishOnMain { self.incomingPairingRequest = nil }
    }

    func rejectPairing() {
        pendingInvitationHandler?(false, nil)
        pendingInvitationHandler = nil
        publishOnMain { self.incomingPairingRequest = nil }
    }

    func disconnect() {
        session?.disconnect()
        publishOnMain {
            self.connectionState = .disconnected
            self.connectedPeerNames = []
        }
    }

    // MARK: - Sending

    func send(command: CommandMessage) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        do {
            let data = try encoder.encode(command)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("❌ PeerSession send error: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func publishOnMain(_ block: @escaping @Sendable () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

// MARK: - MCSessionDelegate

extension PeerSession: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        publishOnMain {
            switch state {
            case .connected:
                if !self.connectedPeerNames.contains(peerID.displayName) {
                    self.connectedPeerNames.append(peerID.displayName)
                }
                let peerRole: DeviceRole = self.currentRole == .sender ? .receiver : .sender
                let device = PairedDevice(
                    id: peerID.displayName,
                    displayName: peerID.displayName,
                    role: peerRole
                )
                self.connectionState = .connected(to: device)
            case .notConnected:
                self.connectedPeerNames.removeAll { $0 == peerID.displayName }
                if self.connectedPeerNames.isEmpty {
                    self.connectionState = .disconnected
                }
            case .connecting:
                self.connectionState = .pairing
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let enc = CommandEncoder()
        do {
            let message = try enc.decode(data)
            publishOnMain { self.handleIncoming(message, from: peerID.displayName) }
        } catch {
            print("❌ PeerSession decode error: \(error)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: - Message Handling (called on main thread)

    private func handleIncoming(_ message: CommandMessage, from peerName: String) {
        switch message.type {
        case .action:
            receivedCommand = message
        case .pairingRequest:
            // Senders request pairing; handled via MC invitation flow
            break
        case .pairingApproval:
            // Connection already established via MCSession delegate
            break
        case .pairingRejection:
            connectionState = .disconnected
        case .heartbeat:
            break
        case .disconnect:
            session?.disconnect()
            connectionState = .disconnected
            connectedPeerNames.removeAll { $0 == peerName }
        case .deviceInfo:
            break
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PeerSession: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let request = IncomingPairingRequest(
            peerID: peerID,
            deviceName: peerID.displayName,
            deviceRole: DeviceRole.sender.rawValue
        )
        pendingInvitationHandler = invitationHandler
        publishOnMain {
            self.incomingPairingRequest = request
            self.connectionState = .pairing
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        publishOnMain {
            self.connectionState = .error(message: "Could not start advertising: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension PeerSession: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        let roleRaw = info?["role"] ?? ""
        let role = DeviceRole(rawValue: roleRaw)
        let peer = DiscoveredPeer(id: peerID.displayName, peerID: peerID, role: role)
        publishOnMain {
            if !self.discoveredPeers.contains(where: { $0.id == peerID.displayName }) {
                self.discoveredPeers.append(peer)
            }
            if case .searching = self.connectionState {
                self.connectionState = .found(peerName: peerID.displayName)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        publishOnMain {
            self.discoveredPeers.removeAll { $0.id == peerID.displayName }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        publishOnMain {
            self.connectionState = .error(message: "Could not browse: \(error.localizedDescription)")
        }
    }
}