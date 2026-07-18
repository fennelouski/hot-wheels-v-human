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
    @State private var tab: Tab = .chassis
    @State private var saved = false

    enum Tab: String, CaseIterable {
        case chassis = "🏎️ Chassis"
        case tires = "🛞 Tires"
        case paint = "🎨 Paint"
        case driver = "🧑‍🚀 Driver"
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Car name", text: $model.design.name)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)

            CarTurntableView(design: model.design)
                .frame(minHeight: 220)

            Picker("Part", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Group {
                switch tab {
                case .chassis: ChassisPicker(selection: $model.design.chassis)
                case .tires: TirePicker(selection: $model.design.tires)
                case .paint: PaintShopView(paint: $model.design.paint)
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
            } label: {
                Text(saved ? "✅ Saved!" : "💾 Save & Race This")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .onChange(of: model.design) { saved = false }
        }
        .padding(.vertical)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
    }
}

/// Live rebuildable turntable preview of the current design.
struct CarTurntableView: View {
    let design: CarDesign

    @State private var spin: EventSubscription?

    var body: some View {
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
        let signature = "\(design.chassis.rawValue)|\(design.paint.colorHex)|\(design.paint.finish.rawValue)"
        guard turntable.components[PreviewSignature.self]?.value != signature else { return }
        turntable.components.set(PreviewSignature(value: signature))
        turntable.children.forEach { $0.removeFromParent() }
        guard let car = try? await AssetStore.shared.entity(named: design.chassis.modelName) else { return }
        CarFactory.paint(car, spec: design.paint)
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
