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
    let id: String
    let peerID: MCPeerID
    let role: DeviceRole?

    var displayName: String { peerID.displayName }
}

// MARK: - PeerSession

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
    private var currentDeviceName: String = ""
    private var autoReconnectEnabled: Bool = true

    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectInterval: TimeInterval = 15.0
    private let baseReconnectInterval: TimeInterval = 1.5
    private var lastConnectedPeerName: String?
    private var isSessionActive: Bool = false

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    func configure(deviceName: String, role: DeviceRole) {
        currentRole = role
        currentDeviceName = deviceName
        autoReconnectEnabled = true
        reconnectAttempts = 0
        createSessionIfNeeded()
    }

    private func createSessionIfNeeded() {
        guard session == nil || peerID?.displayName != currentDeviceName else { return }

        let pid = loadOrCreatePeerID(displayName: currentDeviceName)
        peerID = pid
        let sess = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .required)
        sess.delegate = self
        session = sess
        isSessionActive = true
    }

    private func loadOrCreatePeerID(displayName: String) -> MCPeerID {
        let key = "com.deskboard.peerID.\(displayName)"
        if let data = UserDefaults.standard.data(forKey: key),
           let archived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data),
           archived.displayName == displayName {
            return archived
        }
        let newPeer = MCPeerID(displayName: displayName)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: newPeer, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return newPeer
    }

    // MARK: - Advertising (Receiver)

    func startAdvertising() {
        createSessionIfNeeded()
        guard let pid = peerID else { return }
        stopAdvertising()
        let info: [String: String] = [
            "role": currentRole.rawValue,
            "version": AppConfiguration.appVersion
        ]
        let adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: info, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
        if !isConnected {
            publishOnMain { self.connectionState = .searching }
        }
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Browsing (Sender)

    func startBrowsing() {
        createSessionIfNeeded()
        guard let pid = peerID else { return }
        stopBrowsing()
        let brw = MCNearbyServiceBrowser(peer: pid, serviceType: serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw
        if !isConnected {
            publishOnMain { self.connectionState = .searching }
        }
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        publishOnMain { self.discoveredPeers = [] }
    }

    func stopAll() {
        autoReconnectEnabled = false
        stopReconnectTimer()
        stopHeartbeatTimer()
        stopAdvertising()
        stopBrowsing()
        session?.disconnect()
        session = nil
        peerID = nil
        isSessionActive = false
        publishOnMain {
            self.connectionState = .idle
            self.connectedPeerNames = []
            self.discoveredPeers = []
        }
    }

    // MARK: - Connection

    func invite(peer: DiscoveredPeer) {
        createSessionIfNeeded()
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
        autoReconnectEnabled = false
        stopReconnectTimer()
        stopHeartbeatTimer()
        stopAdvertising()
        stopBrowsing()
        session?.disconnect()
        session = nil
        peerID = nil
        isSessionActive = false
        publishOnMain {
            self.connectionState = .disconnected
            self.connectedPeerNames = []
        }
    }

    func enableAutoReconnect() {
        autoReconnectEnabled = true
        reconnectAttempts = 0
    }

    var isConnected: Bool {
        guard let session else { return false }
        return !session.connectedPeers.isEmpty
    }

    // MARK: - Timers (Separate)

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    private func stopHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func scheduleReconnect() {
        guard autoReconnectEnabled, currentRole != .unset else { return }
        stopReconnectTimer()

        let delay = min(baseReconnectInterval * pow(1.5, Double(reconnectAttempts)), maxReconnectInterval)
        reconnectAttempts += 1

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.attemptReconnect()
            }
        }
    }

    private func attemptReconnect() {
        guard autoReconnectEnabled, currentRole != .unset else { return }
        guard !currentDeviceName.isEmpty else { return }
        guard !isConnected else { return }

        createSessionIfNeeded()

        switch currentRole {
        case .sender:
            startBrowsing()
        case .receiver:
            startAdvertising()
        case .unset:
            break
        }

        scheduleReconnect()
    }

    private func startHeartbeat() {
        stopHeartbeatTimer()
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                if self.isConnected {
                    let msg = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: self.currentDeviceName)
                    self.send(command: msg)
                } else {
                    self.stopHeartbeatTimer()
                    self.scheduleReconnect()
                }
            }
        }
    }

    // MARK: - Auto-Connect Trusted Peers

    private func autoConnectIfTrusted(_ peer: DiscoveredPeer) {
        guard currentRole == .sender else { return }
        guard !isConnected else { return }

        let trustedStore = TrustedDeviceStore.shared
        if trustedStore.isTrusted(id: peer.id) || peer.id == lastConnectedPeerName {
            invite(peer: peer)
        }
    }

    // MARK: - Sending

    func send(command: CommandMessage) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        do {
            let data = try encoder.encode(command)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("PeerSession send error: \(error)")
        }
    }

    // MARK: - Background Support

    func enterBackground() {
        guard isConnected else { return }
        let msg = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: currentDeviceName)
        send(command: msg)
    }

    func enterForeground() {
        guard autoReconnectEnabled, currentRole != .unset else { return }
        if !isConnected {
            reconnectAttempts = 0
            attemptReconnect()
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

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peerName = peerID.displayName
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                if !self.connectedPeerNames.contains(peerName) {
                    self.connectedPeerNames.append(peerName)
                }
                self.lastConnectedPeerName = peerName
                self.reconnectAttempts = 0
                self.stopReconnectTimer()

                let peerRole: DeviceRole = self.currentRole == .sender ? .receiver : .sender
                let device = PairedDevice(
                    id: peerName,
                    displayName: peerName,
                    role: peerRole
                )
                self.connectionState = .connected(to: device)
                self.startHeartbeat()

                TrustedDeviceStore.shared.updateLastSeen(id: peerName)

                if self.currentRole == .sender {
                    self.stopBrowsing()
                }

            case .notConnected:
                self.connectedPeerNames.removeAll { $0 == peerName }
                if self.connectedPeerNames.isEmpty {
                    self.connectionState = .disconnected
                    self.stopHeartbeatTimer()
                    if self.autoReconnectEnabled {
                        self.scheduleReconnect()
                    }
                }

            case .connecting:
                self.connectionState = .pairing

            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let enc = CommandEncoder()
        do {
            let message = try enc.decode(data)
            DispatchQueue.main.async { [weak self] in
                self?.handleIncoming(message, from: peerID.displayName)
            }
        } catch {
            print("PeerSession decode error: \(error)")
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: - Message Handling

    private func handleIncoming(_ message: CommandMessage, from peerName: String) {
        switch message.type {
        case .action:
            receivedCommand = message
        case .pairingRequest:
            break
        case .pairingApproval:
            break
        case .pairingRejection:
            connectionState = .disconnected
        case .heartbeat:
            break
        case .disconnect:
            connectedPeerNames.removeAll { $0 == peerName }
            if connectedPeerNames.isEmpty {
                connectionState = .disconnected
                stopHeartbeatTimer()
                if autoReconnectEnabled {
                    scheduleReconnect()
                }
            }
        case .deviceInfo:
            break
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PeerSession: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let isTrusted = TrustedDeviceStore.shared.isTrusted(id: peerID.displayName)
            if isTrusted {
                invitationHandler(true, self.session)
                return
            }

            let request = IncomingPairingRequest(
                peerID: peerID,
                deviceName: peerID.displayName,
                deviceRole: DeviceRole.sender.rawValue
            )
            self.pendingInvitationHandler = invitationHandler
            self.incomingPairingRequest = request
            self.connectionState = .pairing
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.connectionState = .error(message: "Could not start advertising: \(error.localizedDescription)")
            if self.autoReconnectEnabled {
                self.scheduleReconnect()
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension PeerSession: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        let roleRaw = info?["role"] ?? ""
        let role = DeviceRole(rawValue: roleRaw)
        let peer = DiscoveredPeer(id: peerID.displayName, peerID: peerID, role: role)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.discoveredPeers.contains(where: { $0.id == peerID.displayName }) {
                self.discoveredPeers.append(peer)
            }
            if !self.isConnected {
                self.connectionState = .found(peerName: peerID.displayName)
            }
            self.autoConnectIfTrusted(peer)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredPeers.removeAll { $0.id == peerID.displayName }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.connectionState = .error(message: "Could not browse: \(error.localizedDescription)")
            if self.autoReconnectEnabled {
                self.scheduleReconnect()
            }
        }
    }
}
