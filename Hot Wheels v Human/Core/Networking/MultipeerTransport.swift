//
//  MultipeerTransport.swift
//  Hot Wheels v Human
//
//  MCSession wrapper. Host (TV) advertises `hwvh-race`, players (iPads)
//  browse and auto-invite the first host found. Delegate callbacks arrive
//  on arbitrary queues and hop to the main actor.
//
//  NOTE: requires NSLocalNetworkUsageDescription + NSBonjourServices in
//  Info.plist or discovery silently finds nothing. Needs ≥1 real device —
//  Simulator↔Simulator Multipeer is unreliable by design; don't fight it.
//

import Foundation
import MultipeerConnectivity

@MainActor
final class MultipeerTransport: NSObject, GameTransport {
    static let serviceType = "hwvh-race"

    private(set) var state: TransportState = .idle
    let events: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation

    private let myPeerID = MCPeerID(displayName: deviceDisplayName())
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var role: TransportRole = .player
    private let codec = MessageCodec()

    override init() {
        (events, continuation) = AsyncStream.makeStream()
        super.init()
    }

    func start(role: TransportRole) {
        stop()
        self.role = role
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        setState(.searching)

        switch role {
        case .host:
            let advertiser = MCNearbyServiceAdvertiser(
                peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
            advertiser.delegate = self
            advertiser.startAdvertisingPeer()
            self.advertiser = advertiser
        case .player:
            let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
            browser.delegate = self
            browser.startBrowsingForPeers()
            self.browser = browser
        }
    }

    func send(_ message: GameMessage, reliably: Bool) {
        guard let session, !session.connectedPeers.isEmpty,
              let data = try? codec.encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers,
                          with: reliably ? .reliable : .unreliable)
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        setState(.idle)
    }

    private func setState(_ new: TransportState) {
        guard new != state else { return }
        state = new
        continuation.yield(.stateChanged(new))
    }

    private static func deviceDisplayName() -> String {
        #if os(tvOS)
        return "Living Room TV"
        #else
        // MCPeerID throws NSException for empty or >63-byte names, and
        // hostName can be either (test-runner clones, odd network states).
        let host = ProcessInfo.processInfo.hostName
        guard !host.isEmpty else { return "Racer iPad" }
        return String(decoding: host.utf8.prefix(63), as: UTF8.self)
        #endif
    }
}

// MARK: - Delegates (arbitrary queues → hop to main)

extension MultipeerTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID,
                             didChange sessionState: MCSessionState) {
        Task { @MainActor in
            switch sessionState {
            case .connected:
                self.setState(.connected)
                self.continuation.yield(.peerConnected(peerName: peerID.displayName))
                // Host keeps advertising for a possible second iPad; player
                // stops browsing once latched to a host.
                if self.role == .player { self.browser?.stopBrowsingForPeers() }
            case .notConnected:
                self.continuation.yield(.peerDropped(peerName: peerID.displayName))
                if self.session?.connectedPeers.isEmpty ?? true {
                    self.setState(.dropped)
                    // Auto-reconnect: players resume browsing.
                    if self.role == .player { self.browser?.startBrowsingForPeers() }
                }
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            if let message = try? self.codec.decode(data) {
                self.continuation.yield(.message(message))
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                             withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            invitationHandler(true, self.session)   // v1: trust the living room
        }
    }
}

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard let session = self.session, session.connectedPeers.isEmpty else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
