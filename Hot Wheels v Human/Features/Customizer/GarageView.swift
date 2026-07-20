//
//  GarageView.swift
//  Hot Wheels v Human
//
//  The car hub: the cars a kid owns, the starters, and the body shop full
//  of rides nobody's built yet. Tap any car to see it spin in 3D and do
//  anything to it — race it, rename it, edit it, copy it, scrap it.
//  Mirrors CharacterSelectView so the two "pick your stuff" screens match.
//

import SwiftUI
import SwiftData

struct GarageView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CarDesignRecord.name) private var records: [CarDesignRecord]

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Own header — the system large title renders dark-on-dark
                // over this background regardless of toolbarColorScheme.
                Label("Garage", systemImage: "door.garage.closed")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .padding(.bottom, 8)

                NavigationLink {
                    CustomizerView()
                } label: {
                    Label("Build a New Car", systemImage: "plus.circle.fill")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)

                sectionHeader("My Cars", systemImage: "car.2.fill")
                if records.isEmpty {
                    hint("Nothing here yet — build a car, or grab a starter below!")
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(records) { record in
                            if let design = record.design {
                                carCard(design)
                            }
                        }
                    }
                }

                sectionHeader("Starter Cars", systemImage: "sparkles")
                    .padding(.top, 12)
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(CarDesign.presets) { design in
                        carCard(design, isStarter: true)
                    }
                }

                sectionHeader("Body Shop", systemImage: "wrench.and.screwdriver.fill")
                    .padding(.top, 12)
                hint("Brand-new rides. Pick a body, then paint it however you like.")
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(CarDesign.bodyShop, id: \.model) { body in
                        bodyCard(body)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        // No .navigationTitle: the bar keeps only the back button; the big
        // in-content header above is the title (system large title renders
        // dark-on-dark over this background).
        .onAppear { SoundBank.shared.play("garage_door") }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(.yellow)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    /// Tap opens the car's own page — the preview and every action live
    /// there, so a card is one big target instead of three little ones.
    private func carCard(_ design: CarDesign, isStarter: Bool = false) -> some View {
        let isSelected = appModel.selectedDesign?.id == design.id
        return NavigationLink {
            CarDetailView(design: design, isStarter: isStarter)
        } label: {
            VStack(spacing: 10) {
                CarSwatchView(design: design, size: 96)
                Text(design.name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                if isSelected {
                    Text("RACING NEXT")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(isSelected ? .yellow.opacity(0.2) : .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func bodyCard(_ body: (name: String, model: String, symbol: String)) -> some View {
        NavigationLink {
            CustomizerView(design: CarDesign.newCar(body: body))
        } label: {
            VStack(spacing: 10) {
                Image(systemName: body.symbol)
                    .font(.system(size: 44, weight: .bold))
                    .frame(height: 96)
                Text(body.name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

/// One car, big: the 3D turntable preview plus every action the garage can
/// take on it. Starters are read-only — editing or copying one makes a
/// personal car, so the built-ins stay pristine (CharacterSelectView's rule).
struct CarDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let isStarter: Bool
    @State private var design: CarDesign
    @State private var testing = false

    init(design: CarDesign, isStarter: Bool = false) {
        self.isStarter = isStarter
        _design = State(initialValue: design)
    }

    var body: some View {
        // Deliberately NOT a ScrollView: the turntable's drag-to-orbit and a
        // vertical scroll would both claim the same finger. The turntable
        // gives up height instead (as in CustomizerView), so it all fits.
        VStack(spacing: 20) {
                // The preview the garage never had: the real car, built by
                // the same code that races it.
                CarTurntableView(design: design)
                    .frame(minHeight: 200, maxHeight: 320)

                if isStarter {
                    Text(design.name)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                } else {
                    // Rename in place — to a kid the name IS the car, and
                    // it shouldn't cost a trip through the whole builder.
                    TextField("Car name", text: $design.name)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .onChange(of: design.name) { modelContext.saveDesign(design) }
                }

                // Bars come straight off RaceTuning, so they can't lie
                // about the physics (same rule as ChassisPicker).
                VStack(spacing: 8) {
                    StatBar(name: "Speed", value: normalized(RaceTuning.maxSpeed[design.chassis]!,
                                                             among: RaceTuning.maxSpeed))
                    StatBar(name: "Weight", value: normalized(design.chassis.mass,
                                                              among: RaceTuning.chassisMass))
                    StatBar(name: "Grip", value: normalized(design.tires.staticFriction,
                                                            among: RaceTuning.tireStaticFriction))
                }
                .frame(maxWidth: 340)

                TryItButton(title: "RACE THIS ONE!", systemImage: "flag.checkered") {
                    appModel.selectedDesign = design
                    SoundBank.shared.play("car_select_vroom")
                    dismiss()
                }

                // Wraps on narrower splits instead of squeezing below 60 pt.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { actions }
                    VStack(spacing: 16) { actions }
                }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        // Coming back from "Edit It" — @State was seeded before the edit, so
        // without this the turntable shows the car as it was, which reads as
        // "my paint didn't save".
        .onAppear {
            if let fresh = modelContext.carRecord(design.id)?.design {
                design = fresh
            }
        }
        .racePreview(isPresented: $testing,
                     designs: [appModel.stampedRaceDesign(car: design)])
    }

    @ViewBuilder
    private var actions: some View {
        NavigationLink {
            // Editing a starter edits a personal copy — presets stay pristine.
            CustomizerView(design: isStarter ? personalCopy() : design)
        } label: {
            actionLabel(isStarter ? "Remix It" : "Edit It", systemImage: "pencil")
        }
        .buttonStyle(.bordered)
        .tint(.yellow)

        Button {
            testing = true
        } label: {
            actionLabel("Test Drive", systemImage: "play.fill")
        }
        .buttonStyle(.bordered)
        .tint(.yellow)

        Button(action: makeCopy) {
            actionLabel("Make a Copy", systemImage: "doc.on.doc.fill")
        }
        .buttonStyle(.bordered)
        .tint(.yellow)

        if !isStarter {
            Button(role: .destructive, action: scrap) {
                actionLabel("Scrap It", systemImage: "trash.fill")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 24, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 20)
            .frame(minHeight: 60)
    }

    private func personalCopy() -> CarDesign {
        var copy = design
        copy.id = UUID()
        return copy
    }

    private func makeCopy() {
        var copy = personalCopy()
        copy.name = "\(design.name) 2"
        modelContext.saveDesign(copy)
        SoundBank.shared.play("confirm_sparkle")
        dismiss()
    }

    private func scrap() {
        guard let record = modelContext.carRecord(design.id) else { return }
        if appModel.selectedDesign?.id == design.id {
            appModel.selectedDesign = nil
        }
        modelContext.delete(record)
        try? modelContext.save()
        SoundBank.shared.play("piece_delete_pop")
        dismiss()
    }
}

/// The card's paint swatch: the design's actual look — paint color with the
/// livery/sticker/drawing overlay composited on top — instead of a bare
/// circle. Renders once per design id (OverlayComposer is pure CG).
struct CarSwatchView: View {
    let design: CarDesign
    var size: CGFloat = 54

    @State private var overlay: CGImage?

    var body: some View {
        Circle()
            .fill(Color(hex: design.paint.colorHex))
            .overlay {
                if let overlay {
                    Image(decorative: overlay, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: size * 0.46))
                }
            }
            .frame(width: size, height: size)
            .task(id: design.id) {
                // Pure CG at 256px — milliseconds, fine on the calling task.
                overlay = OverlayComposer.render(
                    livery: design.livery, stickers: design.stickers,
                    drawing: design.drawingPNG, size: 256)
            }
    }
}

#Preview {
    NavigationStack { GarageView() }
        .environment(AppModel())
        .modelContainer(for: [CarDesignRecord.self, DriverProfileRecord.self],
                        inMemory: true)
}
