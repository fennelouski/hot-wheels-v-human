import SwiftUI

#if os(tvOS)
/// One remote, two upright workshops. Each player's car draft and chosen
/// racer survive switching between the benches before the local race.
struct TVTwoPlayerCustomizerView: View {
    @Environment(AppModel.self) private var appModel
    @State private var first = CustomizerModel()
    @State private var second = CustomizerModel()
    @State private var player = 1
    @State private var seeded = false
    @State private var firstDriver: DriverProfile?
    @State private var secondDriver: DriverProfile?
    @State private var racing = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                Text("Player \(player)'s Car")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                Spacer()
                if player == 2 {
                    Button {
                        secondDriver = appModel.raceDriver
                        appModel.selectedDriver = firstDriver
                        player = 1
                    } label: { Label("Player 1", systemImage: "arrow.left") }
                    .buttonStyle(TVWorkshopButtonStyle())
                }
                Button {
                    if player == 1 {
                        firstDriver = appModel.raceDriver
                        appModel.selectedDesign = first.design
                        appModel.selectedDriver = secondDriver
                        player = 2
                    } else {
                        secondDriver = appModel.raceDriver
                        appModel.playerTwoDesign = second.design
                        racing = true
                    }
                } label: {
                    Label(player == 1 ? "Player 2" : "Race Together", systemImage: player == 1 ? "arrow.right" : "flag.checkered")
                }
                .buttonStyle(TVWorkshopButtonStyle())
                .accessibilityIdentifier("tv-two-player-next")
            }
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .padding(.horizontal, 36)
            .focusSection()
            TVCustomizerView(model: player == 1 ? first : second, isPlayerTwo: player == 2)
                .id(player)
        }
        .padding(.top, 20)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .onAppear {
            guard !seeded else { return }
            seeded = true
            if let design = appModel.selectedDesign { first.design = design }
            if let design = appModel.playerTwoDesign { second.design = design }
            firstDriver = appModel.raceDriver
            secondDriver = appModel.raceDriver
        }
        .racePreview(isPresented: $racing,
                     designs: [appModel.stampedRaceDesign(car: first.design, driver: firstDriver),
                               appModel.stampedRaceDesign(car: second.design, driver: secondDriver)],
                     blueprint: appModel.raceBlueprint,
                     config: MatchConfig(mode: .twoPlayer))
    }
}
#endif
