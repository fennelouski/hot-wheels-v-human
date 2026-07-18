//
//  FaceDecals.swift
//  Hot Wheels v Human
//
//  Face expression per reaction state. The README's texture-swap quad
//  became an emoji badge composited over the PiP in SwiftUI — reads
//  even better at PiP size and needs zero texture authoring.
//  ponytail: swap to textured face quads only if the emoji look wears thin.
//

nonisolated enum FaceDecals {
    static func emoji(for state: ReactionState) -> String {
        switch state {
        case .idle: "🙂"
        case .steerLeft, .steerRight: "😯"
        case .braced: "😬"
        case .boosted: "🤩"
        case .crashed: "😵‍💫"
        case .celebrating: "🥳"
        }
    }
}
