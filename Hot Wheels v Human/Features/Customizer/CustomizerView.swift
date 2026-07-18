//
//  CustomizerView.swift
//  Hot Wheels v Human
//
//  Tabbed car builder with live 3D turntable. The preview is built by the
//  same paint code that races — what you see is what races.
//

import SwiftUI
import SwiftData
import RealityKit

struct CustomizerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    /// 2P split: the top half saves into playerTwoDesign.
    var isPlayerTwo = false

    @State private var model = CustomizerModel()
    @State private var tab: Tab =
        ProcessInfo.processInfo.arguments.contains("--demo-design") ? .paint : .chassis
    @State private var saved = false
    @State private var paintSlot = CarPaintSlot.body

    enum Tab: String, CaseIterable {
        case chassis = "Chassis"
        case tires = "Tires"
        case paint = "Paint"
        case livery = "Livery"
        case driver = "Driver"

        var symbolName: String {
            switch self {
            case .chassis: "car.side.fill"
            case .tires: "circle.circle"
            case .paint: "paintbrush.fill"
            case .livery: "flame.fill"
            case .driver: "person.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Car name", text: $model.design.name)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)

            CarTurntableView(design: model.design) { partName in
                paintSlot = CarPaintSlot.slot(forPartName: partName)
                tab = .paint
                SoundBank.shared.play("ui_tap")
            }
            .frame(minHeight: 220)
            .overlay(alignment: .topLeading) {
                Button {
                    model.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
            }

            Picker("Part", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Label($0.rawValue, systemImage: $0.symbolName) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Group {
                switch tab {
                case .chassis: ChassisPicker(selection: $model.design.chassis)
                case .tires: TirePicker(selection: $model.design.tires)
                case .paint: PaintShopView(design: $model.design, slot: $paintSlot)
                case .livery: LiveryShopView(livery: $model.design.livery)
                case .driver: DriverEditorView(driver: $model.driver)
                }
            }
            .frame(maxHeight: 240)

            Button {
                model.save(into: modelContext)
                if isPlayerTwo {
                    appModel.playerTwoDesign = model.design
                } else {
                    appModel.selectedDesign = model.design
                }
                saved = true
                SoundBank.shared.play("confirm_sparkle")
            } label: {
                Label(saved ? "Saved!" : "Save & Race This",
                      systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .onChange(of: model.design) { old, _ in
                saved = false
                model.designChanged(from: old)
            }
        }
        .padding(.vertical)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
    }
}

/// Live rebuildable turntable preview of the current design.
struct CarTurntableView: View {
    let design: CarDesign
    /// Tap a part (body/wheel) on the turntable → part name, for paint-slot
    /// selection. nil = preview is not tappable.
    var onPartTapped: ((String) -> Void)? = nil

    @State private var spin: EventSubscription?

    var body: some View {
        // SpatialTapGesture doesn't exist on tvOS; the customizer only runs
        // on iPad, the TV merely compiles this file.
        #if os(tvOS)
        realityView
        #else
        realityView
            .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
                onPartTapped?(value.entity.name)
            })
        #endif
    }

    private var realityView: some View {
        RealityView { content in
            content.camera = .virtual
            let turntable = Entity()
            turntable.name = "turntable"
            content.add(turntable)

            let camera = PerspectiveCamera()
            camera.look(at: .zero, from: [0, 0.14, -0.32], relativeTo: nil)
            content.add(camera)
            let light = DirectionalLight()
            light.light.intensity = 5000
            light.look(at: .zero, from: [1, 2, -2], relativeTo: nil)
            content.add(light)

            await Self.rebuild(turntable, design: design)
            spin = content.subscribe(to: SceneEvents.Update.self) { event in
                turntable.transform.rotation *= simd_quatf(
                    angle: Float(event.deltaTime) * 1.0, axis: [0, 1, 0])
            }
        } update: { content in
            guard let turntable = content.entities.first(where: { $0.name == "turntable" }) else { return }
            Task { @MainActor in
                await Self.rebuild(turntable, design: design)
            }
        }
    }

    @MainActor
    private static func rebuild(_ turntable: Entity, design: CarDesign) async {
        let parts = (design.partColors ?? [:]).sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        let livery = design.livery.map {
            "\($0.pattern.rawValue)/\($0.colorHex)/\($0.scale)"
        } ?? "none"
        let signature = "\(design.chassis.rawValue)|\(design.paint.colorHex)|\(design.paint.finish.rawValue)|\(parts)|\(livery)"
        guard turntable.components[PreviewSignature.self]?.value != signature else { return }
        turntable.components.set(PreviewSignature(value: signature))
        turntable.children.forEach { $0.removeFromParent() }
        guard let car = try? await AssetStore.shared.entity(named: design.chassis.modelName) else { return }
        await CarFactory.applyCustomization(to: car, design: design)
        // Make each painted part tappable for paint-slot selection.
        car.generateCollisionShapes(recursive: true)
        for part in car.descendantsAndSelf() where part.components.has(ModelComponent.self) {
            part.components.set(InputTargetComponent())
        }
        let bounds = car.visualBounds(relativeTo: nil)
        car.position = -bounds.center
        turntable.addChild(car)
    }
}

/// Skips redundant preview rebuilds (update: fires on every SwiftUI tick).
struct PreviewSignature: Component {
    let value: String
}

#Preview {
    CustomizerView()
        .environment(AppModel())
        .modelContainer(for: [CarDesignRecord.self, DriverProfileRecord.self], inMemory: true)
}
