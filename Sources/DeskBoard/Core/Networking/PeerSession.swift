import Foundation
import os.log
import AVFAudio
@preconcurrency import MultipeerConnectivity
@preconcurrency import KeychainAccess

private let peerLog = Logger(subsystem: "com.deskboard", category: "PeerSession")

nonisolated struct IncomingPairingRequest: @unchecked Sendable, Identifiable {
    var id: String { peerID.displayName }
    let peerID: MCPeerID
    let deviceName: String
    let deviceRole: String
    let deviceUUID: String?
    let pairingToken: String?
}

nonisolated struct DiscoveredPeer: Identifiable, @unchecked Sendable {
    let id: String
    let peerID: MCPeerID
    let role: DeviceRole?
    let deviceUUID: String?
    let pairingToken: String?

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
    private var lastConnectedPeerUUID: String?
    private var isSessionActive: Bool = false
    private var sessionGeneration: UInt64 = 0
    private var lastDataReceivedTime: Date = Date()
    private var lastHeartbeatSentTime: Date = Date()
    private var staleMissCount: Int = 0
    private var isReconnecting: Bool = false
    private var pendingInvitePeers: Set<String> = []
    private var pendingInviteTimestamps: [String: Date] = [:]
    private var isInForeground: Bool = true
    private var backgroundNetworkingEnabled: Bool = false
    private var isServicesRunning: Bool = false
    private var isEnteringForeground: Bool = false

    private let staleConnectionTimeout: TimeInterval = 90
    private let maxStaleMisses: Int = 3
    private let inviteRetryCooldown: TimeInterval = 12
    private var canRunNetworking: Bool { isInForeground || backgroundNetworkingEnabled }

    private let timerQueue = DispatchQueue(label: "com.deskboard.peersession.timers", qos: .userInitiated)
    private let sessionLock = NSLock()

    private nonisolated(unsafe) static let keychainService = Keychain(service: "com.deskboard.device-identity")
    private static let deviceUUIDKey = "deviceUUID"
    private static let pairingTokenKey = "pairingToken"
    private static let lastPeerUUIDKey = "lastConnectedPeerUUID"
    private static let lastPeerNameKey = "lastConnectedPeerName"
    private static let lastConnectionTimestampKey = "lastConnectionTimestamp"

    private struct InvitationContext: Codable, Sendable {
        let deviceUUID: String
        let pairingToken: String
        let deviceRole: String
        let deviceName: String
        let appVersion: String
    }

    private struct SendableInvitationHandler: @unchecked Sendable {
        let handler: (Bool, MCSession?) -> Void
    }

    private static func decodeInvitationContext(_ data: Data?) -> InvitationContext? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(InvitationContext.self, from: data)
    }

    static var stableDeviceUUID: String {
        if let existing = try? keychainService.getString(deviceUUIDKey) {
            return existing
        }
        let newUUID = UUID().uuidString
        try? keychainService.set(newUUID, key: deviceUUIDKey)
        return newUUID
    }

    static var pairingToken: String {
        if let existing = try? keychainService.getString(pairingTokenKey) {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token = Data(bytes).base64EncodedString()
        try? keychainService.set(token, key: pairingTokenKey)
        return token
    }

    private func saveLastConnectedPeer(uuid: String?, name: String) {
        if let uuid {
            try? Self.keychainService.set(uuid, key: Self.lastPeerUUIDKey)
        }
        try? Self.keychainService.set(name, key: Self.lastPeerNameKey)
        try? Self.keychainService.set(ISO8601DateFormatter().string(from: Date()), key: Self.lastConnectionTimestampKey)
    }

    private func loadLastConnectedPeer() -> (uuid: String?, name: String?, timestamp: Date?) {
        let uuid = try? Self.keychainService.getString(Self.lastPeerUUIDKey)
        let name = try? Self.keychainService.getString(Self.lastPeerNameKey)
        var timestamp: Date?
        if let ts = try? Self.keychainService.getString(Self.lastConnectionTimestampKey) {
            timestamp = ISO8601DateFormatter().date(from: ts)
        }
        return (uuid, name, timestamp)
    }

    private override init() {
        super.init()
    }

    func configure(deviceName: String, role: DeviceRole) {
        currentRole = role
        currentDeviceName = deviceName
        reconnectAttempts = 0
        isReconnecting = false
        pendingInvitePeers = []
        pendingInviteTimestamps = [:]
        staleMissCount = 0
        let cached = loadLastConnectedPeer()
        lastConnectedPeerUUID = cached.uuid
        lastConnectedPeerName = cached.name
        rebuildSession()
        registerForPushWake()
    }

    private func rebuildSession() {
        sessionLock.lock()

        stopAdvertisingInternal()
        stopBrowsingInternal()

        guard !currentDeviceName.isEmpty else {
            isSessionActive = false
            sessionLock.unlock()
            return
        }

        let pid = loadOrCreatePeerID(displayName: currentDeviceName)
        peerID = pid

        session?.disconnect()
        session?.delegate = nil

        let sess = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .required)
        sess.delegate = self
        session = sess
        sessionGeneration &+= 1
        isSessionActive = true
        lastDataReceivedTime = Date()
        staleMissCount = 0
        pendingInvitePeers = []
        pendingInviteTimestamps = [:]
        sessionLock.unlock()

        updateOnMain {
            self.connectedPeerNames = []
            self.discoveredPeers = []
            self.incomingPairingRequest = nil
        }
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
        guard let pid = peerID, let _ = session else {
            sessionLock.unlock()
            return
        }
        stopAdvertisingInternal()
        let info: [String: String] = [
            "role": currentRole.rawValue,
            "version": AppConfiguration.appVersion,
            "deviceUUID": Self.stableDeviceUUID,
            "pairingToken": Self.pairingToken
        ]
        let adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: info, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
        let connected = session?.connectedPeers.isEmpty == false
        sessionLock.unlock()
        if !connected {
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
        guard let pid = peerID, let _ = session else {
            sessionLock.unlock()
            return
        }
        stopBrowsingInternal()
        let brw = MCNearbyServiceBrowser(peer: pid, serviceType: serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw
        let connected = session?.connectedPeers.isEmpty == false
        sessionLock.unlock()
        if !connected {
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
    }

    func startAllServices() {
        guard currentRole != .unset, !currentDeviceName.isEmpty else { return }
        sessionLock.lock()
        let alreadyRunning = advertiser != nil && browser != nil
        sessionLock.unlock()
        guard !alreadyRunning else { return }
        startAdvertising()
        startBrowsing()
        isServicesRunning = true
    }

    func stopAll() {
        autoReconnectEnabled = false
        isReconnecting = false
        isServicesRunning = false
        isEnteringForeground = false
        backgroundNetworkingEnabled = false
        pendingInvitePeers = []
        pendingInviteTimestamps = [:]
        staleMissCount = 0
        BackgroundKeepAliveService.shared.stop()
        cancelAllTimers()
        sessionLock.lock()
        stopAdvertisingInternal()
        stopBrowsingInternal()
        session?.disconnect()
        session?.delegate = nil
        sessionLock.unlock()
        updateOnMain {
            self.connectionState = .idle
            self.connectedPeerNames = []
            self.discoveredPeers = []
        }
    }

    func invite(peer: DiscoveredPeer) {
        pruneExpiredPendingInvites()
        let inviteKey = invitationKey(for: peer)
        if let startedAt = pendingInviteTimestamps[inviteKey],
           Date().timeIntervalSince(startedAt) < inviteRetryCooldown {
            return
        }

        sessionLock.lock()
        guard let session else {
            sessionLock.unlock()
            return
        }
        guard !pendingInvitePeers.contains(inviteKey) else {
            sessionLock.unlock()
            return
        }
        pendingInvitePeers.insert(inviteKey)
        pendingInviteTimestamps[inviteKey] = Date()
        let context = InvitationContext(
            deviceUUID: Self.stableDeviceUUID,
            pairingToken: Self.pairingToken,
            deviceRole: currentRole.rawValue,
            deviceName: currentDeviceName,
            appVersion: AppConfiguration.appVersion
        )
        let contextData = try? JSONEncoder().encode(context)
        browser?.invitePeer(peer.peerID, to: session, withContext: contextData, timeout: 30)
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
        isServicesRunning = false
        isEnteringForeground = false
        backgroundNetworkingEnabled = false
        pendingInvitePeers = []
        pendingInviteTimestamps = [:]
        staleMissCount = 0
        BackgroundKeepAliveService.shared.stop()
        cancelAllTimers()
        sessionLock.lock()
        stopAdvertisingInternal()
        stopBrowsingInternal()
        session?.disconnect()
        sessionLock.unlock()
        updateOnMain {
            self.connectionState = .disconnected
            self.connectedPeerNames = []
            self.discoveredPeers = []
        }
    }

    func enableAutoReconnect() {
        autoReconnectEnabled = true
        reconnectAttempts = 0
        isReconnecting = false
    }

    func setAutoReconnectEnabled(_ enabled: Bool) {
        autoReconnectEnabled = enabled
        if enabled {
            reconnectAttempts = 0
            isReconnecting = false
            return
        }
        backgroundNetworkingEnabled = false
        BackgroundKeepAliveService.shared.stop()
        isReconnecting = false
        pendingInvitePeers = []
        pendingInviteTimestamps = [:]
        stopReconnectTimer()
    }

    var isConnected: Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        guard let session else { return false }
        return !session.connectedPeers.isEmpty
    }

    // MARK: - Timers

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
        guard canRunNetworking else { return }
        guard autoReconnectEnabled, currentRole != .unset else { return }
        guard reconnectAttempts < maxReconnectAttempts else { return }
        guard !isReconnecting else { return }
        pruneExpiredPendingInvites()
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
        guard canRunNetworking else {
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
        pruneExpiredPendingInvites()
        if reconnectAttempts % 6 == 0 {
            requestWakeForLastPeer(reason: "reconnect_attempt_\(reconnectAttempts)")
        }

        if reconnectAttempts % 10 == 0 {
            rebuildSession()
            isServicesRunning = false
        }

        startAllServices()

        if let lastUUID = lastConnectedPeerUUID,
           let peer = discoveredPeers.first(where: { $0.deviceUUID == lastUUID }) {
            if shouldInitiateConnection(to: peer.peerID, remoteDeviceUUID: peer.deviceUUID) {
                invite(peer: peer)
            }
            scheduleReconnect()
            return
        }

        if let lastPeer = lastConnectedPeerName,
           let peer = discoveredPeers.first(where: { $0.id == lastPeer }) {
            if shouldInitiateConnection(to: peer.peerID, remoteDeviceUUID: peer.deviceUUID) {
                invite(peer: peer)
            }
        }

        scheduleReconnect()
    }

    private func shouldInitiateConnection(to remotePeer: MCPeerID, remoteDeviceUUID: String? = nil) -> Bool {
        let localKey = Self.stableDeviceUUID
        if let remoteDeviceUUID, localKey != remoteDeviceUUID {
            return localKey.compare(remoteDeviceUUID) == .orderedDescending
        }

        guard let myPeer = peerID else { return false }
        return myPeer.displayName.compare(remotePeer.displayName) == .orderedDescending
    }

    // MARK: - Heartbeat & Stale Detection

    private func startHeartbeat() {
        guard canRunNetworking else { return }
        if heartbeatTimer != nil && staleCheckTimer != nil { return }
        stopHeartbeatTimer()
        stopStaleCheckTimer()
        staleMissCount = 0

        let deviceName = currentDeviceName

        let hbTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        hbTimer.schedule(deadline: .now() + 8.0, repeating: 8.0, leeway: .seconds(1))
        hbTimer.setEventHandler { [weak self] in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                guard strongSelf.canRunNetworking else { return }
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
                guard strongSelf.canRunNetworking else { return }
                guard strongSelf.isConnected else { return }
                let elapsed = Date().timeIntervalSince(strongSelf.lastDataReceivedTime)
                if elapsed > strongSelf.staleConnectionTimeout {
                    strongSelf.staleMissCount += 1
                    if strongSelf.staleMissCount < strongSelf.maxStaleMisses {
                        let msg = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: deviceName)
                        strongSelf.send(command: msg)
                        return
                    }
                    strongSelf.handleStaleConnection()
                } else {
                    strongSelf.staleMissCount = 0
                }
            }
        }
        scTimer.resume()
        staleCheckTimer = scTimer
    }

    private func handleStaleConnection() {
        staleMissCount = 0
        sessionLock.lock()
        let connected = session?.connectedPeers.isEmpty == false
        if connected {
            session?.disconnect()
        }
        sessionLock.unlock()
        guard connected else { return }

        updateOnMain {
            self.connectedPeerNames = []
            self.connectionState = .disconnected
        }
        onConnectionLost()
    }

    private func onConnectionLost() {
        stopHeartbeatTimer()
        stopStaleCheckTimer()
        staleMissCount = 0
        isServicesRunning = false
        pruneExpiredPendingInvites()
        requestWakeForLastPeer(reason: "connection_lost")
        if autoReconnectEnabled && canRunNetworking {
            pendingInvitePeers = []
            pendingInviteTimestamps = [:]
            rebuildSession()
            startAllServices()
            scheduleReconnect()
        }
    }

    private func autoConnectIfTrusted(_ peer: DiscoveredPeer) {
        guard !isConnected else { return }

        let isTrusted = TrustedDeviceStore.shared.isTrusted(
            primaryID: peer.deviceUUID,
            fallbackID: peer.id
        )
        let wasRecentlyConnected = peer.id == lastConnectedPeerName || peer.deviceUUID == lastConnectedPeerUUID

        guard isTrusted || wasRecentlyConnected else {
            peerLog.info("PAIR-002 Untrusted peer ignored: \(peer.displayName)")
            return
        }

        if isTrusted, let token = peer.pairingToken {
            updateOnMain { self.connectionState = .verifyingTrustedDevice(name: peer.displayName) }
            if !TrustedDeviceStore.shared.validateToken(
                primaryID: peer.deviceUUID,
                fallbackID: peer.id,
                token: token
            ) {
                peerLog.warning("PAIR-001 Token mismatch for peer \(peer.displayName)")
                updateOnMain { self.connectionState = .searching }
                return
            }
        }

        guard shouldInitiateConnection(to: peer.peerID, remoteDeviceUUID: peer.deviceUUID) else { return }

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
            peerLog.error("SEND-001 Failed to send \(command.type.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Lifecycle

    func enterBackground() {
        isInForeground = false
        isEnteringForeground = false
        let shouldKeepAlive = autoReconnectEnabled && currentRole == .receiver
        backgroundNetworkingEnabled = BackgroundKeepAliveService.shared.setActive(shouldKeepAlive)
        if isConnected {
            let msg = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: currentDeviceName)
            send(command: msg)
        }
        if backgroundNetworkingEnabled {
            if isConnected {
                startHeartbeat()
            } else if autoReconnectEnabled {
                requestWakeForLastPeer(reason: "entered_background")
                scheduleReconnect()
            }
            return
        }
        cancelAllTimers()
    }

    func enterForeground() {
        isInForeground = true
        backgroundNetworkingEnabled = false
        BackgroundKeepAliveService.shared.stop()
        guard autoReconnectEnabled, currentRole != .unset else { return }
        guard !isEnteringForeground else {
            peerLog.info("LIFECYCLE-001 enterForeground already in progress, skipping")
            return
        }
        isEnteringForeground = true

        lastDataReceivedTime = Date()
        registerForPushWake()

        if !isConnected {
            reconnectAttempts = 0
            isReconnecting = false
            pendingInvitePeers = []
            rebuildSession()
            startAllServices()
            attemptFastResume()
            scheduleReconnect()
        } else {
            startHeartbeat()

            sessionLock.lock()
            let hasAdvertiser = advertiser != nil
            let hasBrowser = browser != nil
            sessionLock.unlock()

            if !hasAdvertiser || !hasBrowser {
                isServicesRunning = false
                startAllServices()
            }
        }
        isEnteringForeground = false
    }

    func attemptQuickReconnect() {
        guard autoReconnectEnabled else { return }
        guard currentRole != .unset, !currentDeviceName.isEmpty else { return }
        guard !isConnected else { return }
        pendingInvitePeers = []
        pendingInviteTimestamps = [:]
        rebuildSession()
        startAllServices()
    }

    private func attemptFastResume() {
        let lastPeer = loadLastConnectedPeer()
        guard let lastPeerName = lastPeer.name else {
            peerLog.info("RESUME-001 No cached peer, skipping fast resume")
            return
        }
        lastConnectedPeerUUID = lastPeer.uuid
        if let ts = lastPeer.timestamp, Date().timeIntervalSince(ts) > 24 * 60 * 60 {
            peerLog.info("RESUME-002 Cached peer \(lastPeerName) expired (last seen \(ts))")
            updateOnMain { self.connectionState = .cacheExpired }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                if !self.isConnected {
                    self.connectionState = .searching
                    self.startAllServices()
                }
            }
            return
        }
        self.lastConnectedPeerName = lastPeerName
        peerLog.info("RESUME-003 Reconnecting to last peer: \(lastPeerName)")
        updateOnMain { self.connectionState = .reconnectingToLastDevice(name: lastPeerName) }

        if let lastUUID = lastPeer.uuid,
           let peer = discoveredPeers.first(where: { $0.deviceUUID == lastUUID }) {
            if shouldInitiateConnection(to: peer.peerID, remoteDeviceUUID: peer.deviceUUID) {
                invite(peer: peer)
            }
            return
        }

        if let peer = discoveredPeers.first(where: { $0.id == lastPeerName }) {
            if shouldInitiateConnection(to: peer.peerID, remoteDeviceUUID: peer.deviceUUID) {
                invite(peer: peer)
            }
        }
    }

    func restartServices() {
        guard currentRole != .unset, !currentDeviceName.isEmpty else { return }
        pruneExpiredPendingInvites()
        if !isConnected {
            rebuildSession()
            isServicesRunning = false
        }
        startAllServices()
        registerForPushWake()
        if isConnected && canRunNetworking {
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

    private func invitationKey(for peer: DiscoveredPeer) -> String {
        peer.deviceUUID ?? peer.id
    }

    private func clearPendingInvite(keys: [String]) {
        for key in keys where !key.isEmpty {
            pendingInvitePeers.remove(key)
            pendingInviteTimestamps.removeValue(forKey: key)
        }
    }

    private func pruneExpiredPendingInvites() {
        guard !pendingInviteTimestamps.isEmpty else { return }
        let now = Date()
        let expired = pendingInviteTimestamps.compactMap { key, startedAt in
            now.timeIntervalSince(startedAt) >= inviteRetryCooldown ? key : nil
        }
        clearPendingInvite(keys: expired)
    }

    private func registerForPushWake() {
        guard currentRole != .unset else { return }
        let role = currentRole
        let deviceName = currentDeviceName
        guard !deviceName.isEmpty else { return }
        Task {
            await PushWakeService.shared.registerCurrentDevice(role: role, deviceName: deviceName)
        }
    }

    private func requestWakeForLastPeer(reason: String) {
        guard autoReconnectEnabled else { return }
        guard let targetUUID = lastConnectedPeerUUID, !targetUUID.isEmpty else { return }
        Task {
            await PushWakeService.shared.wakePeer(targetDeviceUUID: targetUUID, reason: reason)
        }
    }
}

// MARK: - MCSessionDelegate

extension PeerSession: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peerName = peerID.displayName
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.session === session else { return }
            switch state {
            case .connected:
                if !self.connectedPeerNames.contains(peerName) {
                    self.connectedPeerNames.append(peerName)
                }
                self.lastConnectedPeerName = peerName
                self.reconnectAttempts = 0
                self.isReconnecting = false
                self.pendingInvitePeers = []
                self.pendingInviteTimestamps = [:]
                self.stopReconnectTimer()
                self.lastDataReceivedTime = Date()
                self.staleMissCount = 0

                let peerUUID = self.discoveredPeers.first(where: { $0.id == peerName })?.deviceUUID
                self.lastConnectedPeerUUID = peerUUID
                self.saveLastConnectedPeer(uuid: peerUUID, name: peerName)

                let peerRole: DeviceRole = self.currentRole == .sender ? .receiver : .sender
                let device = PairedDevice(
                    id: peerUUID ?? peerName,
                    displayName: peerName,
                    role: peerRole
                )
                self.connectionState = .connected(to: device)
                if self.canRunNetworking {
                    self.startHeartbeat()
                }
                self.registerForPushWake()

                TrustedDeviceStore.shared.updateLastSeen(primaryID: peerUUID, fallbackID: peerName)

            case .notConnected:
                self.connectedPeerNames.removeAll { $0 == peerName }
                let peerUUID = self.discoveredPeers.first(where: { $0.id == peerName })?.deviceUUID
                self.clearPendingInvite(keys: [peerName, peerUUID ?? ""])
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
        let peerName = peerID.displayName
        do {
            let message = try enc.decode(data)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.session === session else { return }
                self.lastDataReceivedTime = Date()
                self.staleMissCount = 0
                self.handleIncoming(message, from: peerName)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.session === session else { return }
                self.lastDataReceivedTime = Date()
                self.staleMissCount = 0
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
        let sendableInvitationHandler = SendableInvitationHandler(handler: invitationHandler)
        let invitationContext = Self.decodeInvitationContext(context)
        let remoteUUID = invitationContext?.deviceUUID
        let remoteToken = invitationContext?.pairingToken
        let remoteRole = invitationContext?.deviceRole ?? DeviceRole.sender.rawValue
        let remoteName = invitationContext?.deviceName ?? peerDisplayName
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                sendableInvitationHandler.handler(false, nil)
                return
            }

            let isTrusted = TrustedDeviceStore.shared.isTrusted(
                primaryID: remoteUUID,
                fallbackID: peerDisplayName
            )
            let wasRecentlyConnected = peerDisplayName == self.lastConnectedPeerName || remoteUUID == self.lastConnectedPeerUUID

            if isTrusted, let remoteToken,
               !TrustedDeviceStore.shared.validateToken(primaryID: remoteUUID, fallbackID: peerDisplayName, token: remoteToken) {
                peerLog.warning("PAIR-005 Rejected invitation from \(peerDisplayName) due to token mismatch")
                sendableInvitationHandler.handler(false, nil)
                return
            }

            if isTrusted || wasRecentlyConnected {
                    peerLog.info("PAIR-003 Auto-accepting invitation from \(peerDisplayName): trusted=\(isTrusted), recentlyConnected=\(wasRecentlyConnected)")
                self.sessionLock.lock()
                let sess = self.session
                self.sessionLock.unlock()
                sendableInvitationHandler.handler(true, sess)
                return
            }

            if !self.shouldInitiateConnection(to: capturedPeerID, remoteDeviceUUID: remoteUUID) {
                peerLog.info("PAIR-004 Auto-accepting invitation from \(peerDisplayName): lower priority peer")
                self.sessionLock.lock()
                let sess = self.session
                self.sessionLock.unlock()
                sendableInvitationHandler.handler(true, sess)
                return
            }

            let request = IncomingPairingRequest(
                peerID: capturedPeerID,
                deviceName: remoteName,
                deviceRole: remoteRole,
                deviceUUID: remoteUUID,
                pairingToken: remoteToken
            )
            self.pendingInvitationHandler = sendableInvitationHandler.handler
            self.incomingPairingRequest = request
            self.connectionState = .pairing
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        peerLog.error("ADV-001 Advertiser failed: \(String(describing: error), privacy: .public)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.autoReconnectEnabled && self.canRunNetworking {
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
        let remotePairingToken = info?["pairingToken"]
        let peer = DiscoveredPeer(id: peerID.displayName, peerID: peerID, role: role, deviceUUID: deviceUUID, pairingToken: remotePairingToken)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pruneExpiredPendingInvites()
            if let role, role == self.currentRole {
                return
            }
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
            guard let self else { return }
            let peerUUID = self.discoveredPeers.first(where: { $0.id == peerID.displayName })?.deviceUUID
            self.discoveredPeers.removeAll { $0.id == peerID.displayName }
            self.clearPendingInvite(keys: [peerID.displayName, peerUUID ?? ""])
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        peerLog.error("BRW-001 Browser failed: \(String(describing: error), privacy: .public)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.autoReconnectEnabled && self.canRunNetworking {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.startBrowsing()
                }
            }
        }
    }
}

private let keepAliveLog = Logger(subsystem: "com.deskboard", category: "BackgroundKeepAlive")

private final class BackgroundKeepAliveService: @unchecked Sendable {
    static let shared = BackgroundKeepAliveService()

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private(set) var isRunning: Bool = false

    private init() {}

    @discardableResult
    func setActive(_ shouldRun: Bool) -> Bool {
        if shouldRun {
            return start()
        }
        stop()
        return false
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let engine = AVAudioEngine()
            let format = engine.outputNode.inputFormat(forBus: 0)
            let node = AVAudioSourceNode { _, _, _, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in buffers {
                    if let data = buffer.mData {
                        memset(data, 0, Int(buffer.mDataByteSize))
                    }
                }
                return noErr
            }

            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0
            try engine.start()

            audioEngine = engine
            sourceNode = node
            isRunning = true
            keepAliveLog.info("BGKA-001 Background keep-alive started")
            return true
        } catch {
            keepAliveLog.error("BGKA-002 Failed to start keep-alive: \(String(describing: error), privacy: .public)")
            stop()
            return false
        }
    }

    func stop() {
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
        }
        audioEngine = nil
        sourceNode = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            keepAliveLog.error("BGKA-003 Failed to deactivate audio session: \(String(describing: error), privacy: .public)")
        }

        if isRunning {
            keepAliveLog.info("BGKA-004 Background keep-alive stopped")
        }
        isRunning = false
    }
}
