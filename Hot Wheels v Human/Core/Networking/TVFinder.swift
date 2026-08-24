//
//  TVFinder.swift
//  Hot Wheels v Human
//
//  Is there an Apple TV to race on right now? A browse-only listener that the
//  iPad home screen keeps running so the "Race on TV" tile appears when a TV
//  is there and stays out of the way when it isn't.
//
//  Deliberately NOT a GameTransport: it never opens an MCSession, never
//  invites, never sends. Discovery is the whole job — MultipeerTransport does
//  the real connecting two screens later, and running a session here would
//  race it for the same peer.
//
//  NOTE: same Info.plist requirements as MultipeerTransport
//  (NSLocalNetworkUsageDescription + NSBonjourServices), and the same
//  Simulator caveat: Simulator↔Simulator discovery is unreliable, so this
//  reports "no TV" there. `--race-on-tv` bypasses the tile for dev.
//

import Foundation
import MultipeerConnectivity
import Observation

@MainActor
@Observable
final class TVFinder: NSObject {
    /// True once at least one Apple TV is advertising `hwvh-race`.
    private(set) var foundTV = false

    /// True when we couldn't even look — Local Network permission denied, or
    /// the browser refused to start. Callers that HIDE a control on `foundTV`
    /// must show it on this, or denying the permission makes the feature
    /// invisible forever with nothing to tap and no way to find out why.
    /// `RaceOnTVView`'s connection ladder already explains the permission;
    /// this is what keeps a kid able to reach it.
    private(set) var blocked = false

    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// Peers by display name. A count, not a bool, so one TV going away while
    /// another is still there doesn't hide the tile.
    @ObservationIgnored private var peers: Set<MCPeerID> = []

    func start() {
        guard browser == nil else { return }
        blocked = false
        let browser = MCNearbyServiceBrowser(
            peer: MCPeerID(displayName: MultipeerTransport.deviceDisplayName()),
            serviceType: MultipeerTransport.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func stop() {
        browser?.stopBrowsingForPeers()
        browser = nil
        peers = []
        foundTV = false
    }
}

extension TVFinder: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            self.peers.insert(peerID)
            self.foundTV = !self.peers.isEmpty
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.peers.remove(peerID)
            self.foundTV = !self.peers.isEmpty
        }
    }

    /// Browsing can fail outright — Local Network permission denied, Wi-Fi
    /// off. That is NOT the same as "there is no TV": we don't know, so say so
    /// and let the caller offer the way in anyway.
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.stop()
            self.blocked = true
        }
    }
}
