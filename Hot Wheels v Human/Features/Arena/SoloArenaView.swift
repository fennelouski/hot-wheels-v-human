//
//  SoloArenaView.swift
//  Hot Wheels v Human
//
//  Arena + mini-Dashboard in one screen, wired through LoopbackTransport —
//  the full networked message flow running in-process. Primary dev loop,
//  and Test Mode's home (MatchConfig.mode == .test).
//

import SwiftUI

struct SoloArenaView: View {
    var designs: [CarDesign] = [CarDesign.demoPair[0]]
    var blueprint: TrackBlueprint?
    var config = MatchConfig(mode: .solo)

    @Environment(AppModel.self) private var appModel
    @State private var rig: SoloRig?

    var body: some View {
        // Arena edge to edge, controls floating on top. The sidebar's
        // readouts (progress, lives, speed) already live in the arena
        // HUD's per-racer banner, so only the buttons come along.
        ZStack(alignment: .bottomTrailing) {
            if let rig {
                ArenaView(coordinator: rig.coordinator)
                RaceControlsView(model: rig.dashboard)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.13).ignoresSafeArea())
        .task {
            guard rig == nil else { return }
            let pair = LoopbackTransport.pair()
            let coordinator = RaceCoordinator(transport: pair.host)
            let dashboard = DashboardModel(transport: pair.player, playerName: "Solo Racer")
            coordinator.start()
            dashboard.start()
            dashboard.submitAndReady(designs: designs,
                                     tracks: [blueprint ?? appModel.raceBlueprint],
                                     config: config)
            rig = SoloRig(coordinator: coordinator, dashboard: dashboard)
        }
        .onDisappear {
            rig?.coordinator.stop()
            rig?.dashboard.stop()
        }
    }
}

/// Keeps the loopback pair + both endpoints alive together.
struct SoloRig {
    let coordinator: RaceCoordinator
    let dashboard: DashboardModel
}

/// The buttons that float over the arena when the iPad is both screen and
/// controller. Bottom-trailing on purpose: the reaction-cam PiP sits
/// bottom-leading and the race clock bottom-center. Same 24 pt inset as
/// the PiPs so everything along the bottom edge lines up.
private struct RaceControlsView: View {
    let model: DashboardModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if model.phase == .results {
                Button {
                    model.requestRematch()
                } label: {
                    Label("REMATCH!", systemImage: "arrow.clockwise")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .frame(width: 260, height: 84)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
            } else if let car = model.myCar {
                ReactionCamButton { model.setReactionCam(on: $0) }
                BoostButtonView(meter: car.boostMeter,
                                begin: model.beginBoost, end: model.endBoost)
            }
        }
        .padding(24)
    }
}

extension View {
    /// "Try it now" cover: races whatever the workshop is currently showing,
    /// then drops the kid back on the workbench with their build intact. Every
    /// workshop screen uses this one modifier so the gesture — big play button,
    /// race, X, keep building — is identical wherever you are.
    func racePreview(isPresented: Binding<Bool>,
                     designs: [CarDesign],
                     blueprint: TrackBlueprint? = nil,
                     config: MatchConfig = MatchConfig(mode: .solo)) -> some View {
        modifier(RacePreviewModifier(isPresented: isPresented, designs: designs,
                                     blueprint: blueprint, config: config))
    }
}

private struct RacePreviewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let designs: [CarDesign]
    let blueprint: TrackBlueprint?
    let config: MatchConfig

    /// New identity per presentation — a re-shown cover must build a fresh
    /// race session, not resume the one you just watched.
    @State private var runID = UUID()

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { if $1 { runID = UUID() } }
        // macOS has no fullScreenCover — a sheet is its full-window modal.
        #if os(macOS)
            .sheet(isPresented: $isPresented) { cover }
        #else
            .fullScreenCover(isPresented: $isPresented) { cover }
        #endif
    }

    @ViewBuilder private var cover: some View {
        ZStack(alignment: .topLeading) {
            SoloArenaView(designs: designs, blueprint: blueprint, config: config)
                .id(runID)
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                    .padding(20)
            }
            .tint(.white.opacity(0.7))
            .accessibilityLabel("Close")
        }
    }
}

/// The workshops' shared "try it" button — same words, same shape, same
/// yellow, whether you just built a track, a car, or a racer.
struct TryItButton: View {
    var title: String
    var systemImage: String = "play.fill"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                // Never wrap. In a crowded toolbar SwiftUI would rather stack
                // this into "Se / e it / in / 3D" than overflow, which reads as
                // a broken button; squeezing the neighbouring Spacer is fine.
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(minHeight: 60)
        }
        .buttonStyle(.borderedProminent)
        .tint(.yellow)
        .foregroundStyle(.black)
    }
}

/// Its partner: the quieter "keep this one" button every workshop pairs
/// with `TryItButton`, so saving looks and reads the same everywhere.
struct SaveItButton: View {
    var saved: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(saved ? "Saved!" : "Save it!",
                  systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(minHeight: 60)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    SoloArenaView()
        .environment(AppModel())
}
