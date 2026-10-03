import SwiftUI

#if os(tvOS)
/// Selection stays yellow after focus moves; the white ring follows the remote.
struct TVWorkshopButtonStyle: ButtonStyle {
    var selected = false
    var cornerRadius: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        Surface(label: configuration.label, pressed: configuration.isPressed,
                selected: selected, cornerRadius: cornerRadius)
    }

    private struct Surface: View {
        let label: ButtonStyleConfiguration.Label
        let pressed: Bool
        let selected: Bool
        let cornerRadius: CGFloat
        @Environment(\.isFocused) private var focused
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            label
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .frame(minWidth: 60, minHeight: 60)
                .padding(.horizontal, 14)
                .foregroundStyle(selected ? Color.black : .white)
                .background(selected ? Color.yellow : .white.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(focused ? Color.white : .clear, lineWidth: 4)
                }
                .opacity(enabled ? 1 : 0.4)
                .scaleEffect(reduceMotion ? 1 : pressed ? 0.98 : focused ? 1.035 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: focused)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: pressed)
        }
    }
}

struct TVWorkshopHome: View {
    @Environment(AppModel.self) private var appModel
    @FocusState private var focus: Tile?

    private enum Tile: String, CaseIterable, Hashable {
        case quickPlay, car, track, robot, garage, twoPlayer, racers, iPad

        var title: String {
            switch self {
            case .quickPlay: "Quick Play"
            case .car: "Build a Car"
            case .track: "Build a Track"
            case .robot: "Race a Robot"
            case .garage: "Garage"
            case .twoPlayer: "2-Player Build"
            case .racers: "My Racers"
            case .iPad: "Race with iPad"
            }
        }

        var image: String? {
            switch self {
            case .car: "tile-build-car"
            case .track: "tile-build-track"
            case .robot: "tile-race-robot"
            case .twoPlayer: "tile-two-player"
            case .racers: "tile-my-racers"
            default: nil
            }
        }

        var symbol: String {
            switch self {
            case .quickPlay: "play.fill"
            case .car: "car.side.fill"
            case .track: "point.topleft.down.to.point.bottomright.curvepath"
            case .robot: "hare.fill"
            case .garage: "door.garage.closed"
            case .twoPlayer: "person.2.fill"
            case .racers: "person.crop.square.fill"
            case .iPad: "ipad.and.arrow.forward"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    HStack {
                        Text(AppBranding.name)
                            .font(.system(size: 50, weight: .black, design: .rounded))
                        Spacer()
                        Button {
                            appModel.selectedProfile = nil
                            appModel.selectedDriver = nil
                        } label: {
                            Label(appModel.selectedProfile?.name ?? "Switch Player",
                                  systemImage: "person.crop.circle")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .padding(.horizontal, 24).frame(minHeight: 68)
                        }
                        .buttonStyle(TVWorkshopButtonStyle())
                        .accessibilityIdentifier("tv-switch-profile")
                    }
                    NavigationLink {
                        QuickPlayView()
                    } label: {
                        Label("QUICK PLAY!", systemImage: "play.fill")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 90)
                    }
                    .buttonStyle(TVWorkshopButtonStyle(selected: true))
                    .focused($focus, equals: .quickPlay)
                    .accessibilityIdentifier("tv-home-quickPlay")

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 28), count: 4),
                              spacing: 28) {
                        ForEach(Tile.allCases.filter { $0 != .quickPlay }, id: \.self) { tile in
                            NavigationLink {
                                destination(tile)
                            } label: {
                                VStack(spacing: 12) {
                                    Group {
                                        if let name = tile.image {
                                            bundleImage(name, fallbackSymbol: tile.symbol)
                                                .resizable().scaledToFit()
                                        } else {
                                            Image(systemName: tile.symbol)
                                                .font(.system(size: 76, weight: .semibold))
                                        }
                                    }
                                    .frame(height: 120)
                                    Text(tile.title)
                                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(24).frame(maxWidth: .infinity, minHeight: 222)
                            }
                            .buttonStyle(TVWorkshopButtonStyle())
                            .focused($focus, equals: tile)
                            .accessibilityIdentifier("tv-home-\(tile.rawValue)")
                        }
                    }
                    .focusSection()
                }
                .frame(maxWidth: 1600)
                .padding(32)
                .frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.09, green: 0.10, blue: 0.16).ignoresSafeArea())
            .foregroundStyle(.white)
            .defaultFocus($focus, .quickPlay)
            .onAppear { SoundBank.shared.playMusic("workshop_ambience") }
        }
    }

    @ViewBuilder private func destination(_ tile: Tile) -> some View {
        switch tile {
        case .quickPlay: QuickPlayView()
        case .car: CustomizerView()
        case .track: TrackBuilderView()
        case .robot: RobotRacePickerView()
        case .garage: GarageView()
        case .twoPlayer: CustomizerSplitView()
        case .racers: CharacterSelectView()
        case .iPad: ArenaLobbyView()
        }
    }
}
#endif
