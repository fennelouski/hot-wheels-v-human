//
//  Platform.swift
//  Hot Wheels v Human
//
//  The one place where #if os(tvOS) is expected to be dense.
//

enum Platform {
    #if os(tvOS)
    static let isTV = true
    #else
    static let isTV = false
    #endif
}

/// What the app calls itself on screen.
///
/// "Hot Wheels" is a Mattel trademark (PRD §1.1), so a shipped build must not
/// say it anywhere a player can read — title screen, pairing steps, permission
/// prompts, Home Screen label. Debug builds keep the working title because
/// that's what the family calls it.
///
/// The matching Home Screen label is `INFOPLIST_KEY_CFBundleDisplayName`, set
/// per configuration in the app target. Bundle ID, target name, scheme and the
/// `hwvh-race` Multipeer service are wire/tooling identifiers and stay put.
enum AppBranding {
    #if DEBUG
    static let name = "Hot Wheels vs Humans"
    #else
    static let name = "HWvH"
    #endif
}
