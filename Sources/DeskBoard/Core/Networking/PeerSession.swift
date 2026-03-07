import Foundation
@preconcurrency import MultipeerConnectivity
import KeychainAccess

struct IncomingPairingRequest: @unchecked Sendable, Identifiable {
    var id: String { peerID.displayName }
    let peerID: MCPeerID
    let deviceName: String
    let deviceRole: String
}

struct DiscoveredPeer: Identifiable, @unchecked Sendable {
    let id: String
    let peerID: MCPeerID
    let role: DeviceRole?
    let deviceUUID: String?

    var displayName: String { peerID.displayName }
}

final class PeerSession: NSObject, @unchecked Sendable, ObservableObject {

    static let shared = PeerSession()

    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var discoveredPeers: [DiscoveredPeer] = []
    @Published private(set) var connectedPeerNames: [String] = []
    @Published private(set) var receivedCommand: CommandMessage?
    @Published private(set) var incomingPairingRequest: IncomingPairingRequest?

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

    private var reconnectTimer: DispatchSourceTimer?
    private var heartbeatTimer: DispatchSourceTimer?
    private var staleCheckTimer: DispatchSourceTimer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 500
    private var lastConnectedPeerName: String?
    private var isSessionActive: Bool = false
    private var lastDataReceivedTime: Date = Date()
    private var lastHeartbeatSentTime: Date = Date()
    private var isReconnecting: Bool = false
    private var pendingInvitePeers: Set<String> = []
    private var isInForeground: Bool = true

    private let timerQueue = DispatchQueue(label: "com.deskboard.peersession.timers", qos: .userInitiated)
    private let sessionLock = NSLock()

    private static let keychainService = Keychain(service: "com.deskboard.device-identity")
    private static let deviceUUIDKey = "deviceUUID"

    static var stableDeviceUUID: String {
        if let existing = try? keychainService.getString(deviceUUIDKey) {
            return existing
        }
        let newUUID = UUID().uuidString
        try? keychainService.set(newUUID, key: deviceUUIDKey)
        return newUUID
    }

    private override init() {
        super.init()
    }

    func configure(deviceName: String, role: DeviceRole) {
        currentRole = role
        currentDeviceName = deviceName
        autoReconnectEnabled = true
        reconnectAttempts = 0
        isReconnecting = false
        pendingInvitePeers = []
        rebuildSession()
    }

    private func rebuildSession() {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        stopAdvertisingInternal()
        stopBrowsingInternal()

        let pid = loadOrCreatePeerID(displayName: currentDeviceName)
        peerID = pid

        session?.disconnect()
        session?.delegate = nil

        let sess = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .required)
        sess.delegate = self
        session = sess
        isSessionActive = true
        lastDataReceivedTime = Date()
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

    // MARK: - Start / Stop Services

    func startAdvertising() {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        guard let pid = peerID, let _ = session else { return }
        stopAdvertisingInternal()
        let info: [String: String] = [
            "role": currentRole.rawValue,
            "version": AppConfiguration.appVersion,
            "deviceUUID": Self.stableDeviceUUID
        ]
        let adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: info, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
        if !isConnected {
            updateOnMain { self.connectionState = .searching }
        }
    }

    func stopAdvertising() {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        stopAdvertisingInternal()
    }

    private func stopAdvertisingInternal() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
    }

    func startBrowsing() {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        guard let pid = peerID, let _ = session else { return }
        stopBrowsingInternal()
        let brw = MCNearbyServiceBrowser(peer: pid, serviceType: serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw
        if !isConnected {
            updateOnMain { self.connectionState = .searching }
        }
    }

    func stopBrowsing() {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        stopBrowsingInternal()
    }

    private func stopBrowsingInternal() {
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
        updateOnMain { self.discoveredPeers = [] }
    }

    func startAllServices() {
        guard currentRole != .unset, !currentDeviceName.isEmpty else { return }
        startAdvertising()
        startBrowsing()
    }

    func stopAll() {
        autoReconnectEnabled = false
        isReconnecting = false
        pendingInvitePeers = []
        cancelAllTimers()
        sessionLock.lock()
        stopAdvertisingInternal()
        stopBrowsingInternal()
        session?.disconnect()
        sessionLock.unlock()
        updateOnMain {
            self.connectionState = .idle
            self.connectedPeerNames = []
            self.discoveredPeers = []
        }
    }

    func invite(peer: DiscoveredPeer) {
        sessionLock.lock()
        guard let session else {
            sessionLock.unlock()
            return
        }
        guard !pendingInvitePeers.contains(peer.id) else {
            sessionLock.unlock()
            return
        }
        pendingInvitePeers.insert(peer.id)
        browser?.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 30)
        sessionLock.unlock()
        updateOnMain { self.connectionState = .pairing }
    }

    func acceptPairing() {
        sessionLock.lock()
        guard let handler = pendingInvitationHandler, let session else {
            sessionLock.unlock()
            return
        }
        let h = handler
        let s = session
        pendingInvitationHandler = nil
        sessionLock.unlock()
        h(true, s)
        updateOnMain { self.incomingPairingRequest = nil }
    }

    func rejectPairing() {
        let handler = pendingInvitationHandler
        pendingInvitationHandler = nil
        handler?(false, nil)
        updateOnMain { self.incomingPairingRequest = nil }
    }

    func disconnect() {
        autoReconnectEnabled = false
        isReconnecting = false
        pendingInvitePeers = []
        cancelAllTimers()
        sessionLock.lock()
        stopAdvertisingInternal()
        stopBrowsingInternal()
        session?.disconnect()
        sessionLock.unlock()
        updateOnMain {
            self.connectionState = .disconnected
            self.connectedPeerNames = []
        }
    }

    func enableAutoReconnect() {
        autoReconnectEnabled = true
        reconnectAttempts = 0
        isReconnecting = false
    }

    var isConnected: Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        guard let session else { return false }
        return !session.connectedPeers.isEmpty
    }

    // MARK: - Timers (foreground only)

    private func cancelAllTimers() {
        stopReconnectTimer()
        stopHeartbeatTimer()
        stopStaleCheckTimer()
    }

    private func stopReconnectTimer() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    private func stopHeartbeatTimer() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    private func stopStaleCheckTimer() {
        staleCheckTimer?.cancel()
        staleCheckTimer = nil
    }

    private var currentReconnectInterval: TimeInterval {
        if reconnectAttempts < 3 {
            return 0.5
        } else if reconnectAttempts < 10 {
            return 2.0
        } else if reconnectAttempts < 30 {
            return 5.0
        } else {
            return 10.0
        }
    }

    private func scheduleReconnect() {
        guard isInForeground else { return }
        guard autoReconnectEnabled, currentRole != .unset else { return }
        guard reconnectAttempts < maxReconnectAttempts else { return }
        guard !isReconnecting else { return }
        stopReconnectTimer()

        let delay = currentReconnectInterval
        isReconnecting = true

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.attemptReconnect()
            }
        }
        timer.resume()
        reconnectTimer = timer
    }

    private func attemptReconnect() {
        guard isInForeground else {
            isReconnecting = false
            return
        }
        guard autoReconnectEnabled, currentRole != .unset else {
            isReconnecting = false
            return
        }
        guard !currentDeviceName.isEmpty else {
            isReconnecting = false
            return
        }

        if isConnected {
            isReconnecting = false
            return
        }

        reconnectAttempts += 1
        isReconnecting = false

        if reconnectAttempts % 10 == 0 {
            rebuildSession()
        }

        startAllServices()

        if let lastPeer = lastConnectedPeerName {
            for peer in discoveredPeers where peer.id == lastPeer {
                if shouldInitiateConnection(to: peer.peerID) {
                    invite(peer: peer)
                }
                break
            }
        }

        scheduleReconnect()
    }

    private func shouldInitiateConnection(to remotePeer: MCPeerID) -> Bool {
        guard let myPeer = peerID else { return false }
        return myPeer.displayName.compare(remotePeer.displayName) == .orderedDescending
    }

    // MARK: - Heartbeat & Stale Detection (foreground only)

    private func startHeartbeat() {
        guard isInForeground else { return }
        stopHeartbeatTimer()
        stopStaleCheckTimer()

        let deviceName = currentDeviceName

        let hbTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        hbTimer.schedule(deadline: .now() + 8.0, repeating: 8.0, leeway: .seconds(1))
        hbTimer.setEventHandler { [weak self] in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                guard strongSelf.isInForeground else { return }
                if strongSelf.isConnected {
                    let msg = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: deviceName)
                    strongSelf.send(command: msg)
                    strongSelf.lastHeartbeatSentTime = Date()
                } else {
                    strongSelf.onConnectionLost()
                }
            }
        }
        hbTimer.resume()
        heartbeatTimer = hbTimer

        let scTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        scTimer.schedule(deadline: .now() + 25.0, repeating: 15.0, leeway: .seconds(2))
        scTimer.setEventHandler { [weak self] in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                guard strongSelf.isInForeground else { return }
                guard strongSelf.isConnected else { return }
                let elapsed = Date().timeIntervalSince(strongSelf.lastDataReceivedTime)
                if elapsed > 35.0 {
                    strongSelf.handleStaleConnection()
                }
            }
        }
        scTimer.resume()
        staleCheckTimer = scTimer
    }

    private func handleStaleConnection() {
        guard isConnected else { return }
        sessionLock.lock()
        session?.disconnect()
        sessionLock.unlock()

        updateOnMain {
            self.connectedPeerNames = []
            self.connectionState = .disconnected
        }
        onConnectionLost()
    }

    private func onConnectionLost() {
        stopHeartbeatTimer()
        stopStaleCheckTimer()
        if autoReconnectEnabled && isInForeground {
            reconnectAttempts = 0
            pendingInvitePeers = []
            rebuildSession()
            startAllServices()
            scheduleReconnect()
        }
    }

    private func autoConnectIfTrusted(_ peer: DiscoveredPeer) {
        guard !isConnected else { return }

        let isTrusted: Bool
        if let uuid = peer.deviceUUID {
            isTrusted = TrustedDeviceStore.shared.isTrusted(id: uuid)
        } else {
            isTrusted = TrustedDeviceStore.shared.isTrusted(id: peer.id)
        }
        let wasRecentlyConnected = peer.id == lastConnectedPeerName

        guard isTrusted || wasRecentlyConnected else { return }
        guard shouldInitiateConnection(to: peer.peerID) else { return }

        invite(peer: peer)
    }

    // MARK: - Send

    func send(command: CommandMessage) {
        sessionLock.lock()
        guard let sess = session, !sess.connectedPeers.isEmpty else {
            sessionLock.unlock()
            return
        }
        let peers = sess.connectedPeers
        sessionLock.unlock()

        do {
            let data = try encoder.encode(command)
            try sess.send(data, toPeers: peers, with: .reliable)
        } catch {
        }
    }

    // MARK: - Lifecycle

    func enterBackground() {
        isInForeground = false
        if isConnected {
            let msg = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: currentDeviceName)
            send(command: msg)
        }
        cancelAllTimers()
    }

    func enterForeground() {
        isInForeground = true
        guard autoReconnectEnabled, currentRole != .unset else { return }

        lastDataReceivedTime = Date()

        if !isConnected {
            reconnectAttempts = 0
            isReconnecting = false
            pendingInvitePeers = []
            rebuildSession()
            startAllServices()
            scheduleReconnect()
        } else {
            startHeartbeat()

            sessionLock.lock()
            let hasAdvertiser = advertiser != nil
            let hasBrowser = browser != nil
            sessionLock.unlock()

            if !hasAdvertiser || !hasBrowser {
                startAllServices()
            }
        }
    }

    func restartServices() {
        guard currentRole != .unset, !currentDeviceName.isEmpty else { return }
        if !isConnected {
            rebuildSession()
        }
        startAllServices()
        if isConnected && isInForeground {
            startHeartbeat()
        }
    }

    private func updateOnMain(_ block: @escaping @Sendable () -> Void) {
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
                self.isReconnecting = false
                self.pendingInvitePeers = []
                self.stopReconnectTimer()
                self.lastDataReceivedTime = Date()

                let peerRole: DeviceRole = self.currentRole == .sender ? .receiver : .sender
                let device = PairedDevice(
                    id: peerName,
                    displayName: peerName,
                    role: peerRole
                )
                self.connectionState = .connected(to: device)
                if self.isInForeground {
                    self.startHeartbeat()
                }

                TrustedDeviceStore.shared.updateLastSeen(id: peerName)

            case .notConnected:
                self.connectedPeerNames.removeAll { $0 == peerName }
                self.pendingInvitePeers.remove(peerName)
                if self.connectedPeerNames.isEmpty {
                    self.connectionState = .disconnected
                    self.onConnectionLost()
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
                self?.lastDataReceivedTime = Date()
                self?.handleIncoming(message, from: peerID.displayName)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.lastDataReceivedTime = Date()
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

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
                onConnectionLost()
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
        let peerDisplayName = peerID.displayName
        let capturedPeerID = peerID
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                invitationHandler(false, nil)
                return
            }

            let isTrusted = TrustedDeviceStore.shared.isTrusted(id: peerDisplayName)
            let wasRecentlyConnected = peerDisplayName == self.lastConnectedPeerName

            if isTrusted || wasRecentlyConnected {
                self.sessionLock.lock()
                let sess = self.session
                self.sessionLock.unlock()
                invitationHandler(true, sess)
                return
            }

            if !self.shouldInitiateConnection(to: capturedPeerID) {
                self.sessionLock.lock()
                let sess = self.session
                self.sessionLock.unlock()
                invitationHandler(true, sess)
                return
            }

            let request = IncomingPairingRequest(
                peerID: capturedPeerID,
                deviceName: peerDisplayName,
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
            if self.autoReconnectEnabled && self.isInForeground {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.startAdvertising()
                }
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
        let deviceUUID = info?["deviceUUID"]
        let peer = DiscoveredPeer(id: peerID.displayName, peerID: peerID, role: role, deviceUUID: deviceUUID)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let idx = self.discoveredPeers.firstIndex(where: { $0.id == peerID.displayName }) {
                self.discoveredPeers[idx] = peer
            } else {
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
            self?.pendingInvitePeers.remove(peerID.displayName)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.autoReconnectEnabled && self.isInForeground {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.startBrowsing()
                }
            }
        }
    }
}
