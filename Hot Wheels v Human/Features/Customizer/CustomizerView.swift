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
#if canImport(PencilKit) && !os(tvOS)
import PencilKit
#endif

struct CustomizerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    /// 2P split: the top half saves into playerTwoDesign.
    var isPlayerTwo = false

    @State private var model = CustomizerModel()
    @State private var tab: Tab = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--demo-driver") { return .driver }
        return args.contains("--demo-design") ? .draw : .chassis
    }()
    @State private var saved = false
    @State private var paintSlot = CarPaintSlot.body
    @State private var armedSticker: String? = nil
    @State private var stickerColor = "#F2F2F7"
    /// Mid-gesture sticker state shown on the turntable; committed to the
    /// design (one undo entry) when the gesture ends.
    @State private var draftStickers: [StickerPlacement]? = nil
    #if canImport(PencilKit) && !os(tvOS)
    /// Session-held pencil strokes (the design only stores the capped PNG).
    @State private var pencilStrokes = PKDrawing()
    @State private var faceStrokes = PKDrawing()
    #endif

    enum Tab: String, CaseIterable {
        case chassis = "Chassis"
        case tires = "Tires"
        case paint = "Paint"
        case livery = "Livery"
        case stickers = "Stickers"
        case draw = "Draw"
        case driver = "Driver"

        var symbolName: String {
            switch self {
            case .chassis: "car.side.fill"
            case .tires: "circle.circle"
            case .paint: "paintbrush.fill"
            case .livery: "flame.fill"
            case .stickers: "star.circle.fill"
            case .draw: "pencil.tip"
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

            CarTurntableView(
                design: displayDesign,
                onPartTapped: { partName in
                    paintSlot = CarPaintSlot.slot(forPartName: partName)
                    tab = .paint
                    SoundBank.shared.play("ui_tap")
                },
                onSurfaceTapped: armedSticker.map { symbol in
                    { uv in
                        var stickers = model.design.stickers ?? []
                        stickers.append(StickerPlacement(
                            symbol: symbol, uv: ShellGeometry.clampStickerUV(uv),
                            scale: 1, rotation: 0, colorHex: stickerColor))
                        model.design.stickers = stickers
                        SoundBank.shared.play("customize_confirm_pop")
                    }
                },
                onSurfaceDragged: { uv, ended in
                    editNewestSticker(ended: ended) { $0.uv = ShellGeometry.clampStickerUV(uv) }
                },
                onPinch: { magnification, ended in
                    editNewestSticker(ended: ended) {
                        $0.scale = max(0.3, min(committedNewestSticker?.scale ?? 1, 4) * magnification)
                    }
                },
                onRotate: { radians, ended in
                    editNewestSticker(ended: ended) {
                        $0.rotation = (committedNewestSticker?.rotation ?? 0) + radians
                    }
                }
            )
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
                case .stickers: StickerShopView(armed: $armedSticker, colorHex: $stickerColor)
                case .draw:
                    #if canImport(PencilKit) && !os(tvOS)
                    DrawingPadView(drawingPNG: $model.design.drawingPNG,
                                   drawingStrokes: $model.design.drawingStrokes,
                                   strokes: $pencilStrokes)
                    #else
                    Text("Drawing needs the iPad")
                    #endif
                case .driver:
                    // Face pad + editor overflow portrait width — kid swipes.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 28) {
                            #if canImport(PencilKit) && !os(tvOS)
                            FaceDrawPad(faceDrawingPNG: $model.design.faceDrawingPNG,
                                        strokes: $faceStrokes)
                            #endif
                            DriverEditorView(driver: $model.driver)
                        }
                        .padding(.horizontal, 20)
                    }
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

    /// The design the turntable shows: mid-gesture sticker drafts override
    /// the saved list so previews track the finger without flooding undo.
    private var displayDesign: CarDesign {
        var design = model.design
        if let draftStickers { design.stickers = draftStickers }
        return design
    }

    private var committedNewestSticker: StickerPlacement? {
        model.design.stickers?.last
    }

    /// Apply `change` to the newest sticker: live via the draft, committed
    /// into the design (single undo entry + sound) when the gesture ends.
    private func editNewestSticker(ended: Bool,
                                   _ change: (inout StickerPlacement) -> Void) {
        var stickers = draftStickers ?? model.design.stickers ?? []
        guard !stickers.isEmpty else { return }
        change(&stickers[stickers.count - 1])
        if ended {
            model.design.stickers = stickers
            draftStickers = nil
            SoundBank.shared.play("ui_tap")
        } else {
            draftStickers = stickers
        }
    }
}

/// Live rebuildable turntable preview of the current design.
struct CarTurntableView: View {
    let design: CarDesign
    /// Tap a part (body/wheel) on the turntable → part name, for paint-slot
    /// selection. nil = preview is not tappable.
    var onPartTapped: ((String) -> Void)? = nil
    /// Set when a sticker is armed: tap → shell UV of the hit. Wins over
    /// onPartTapped while set.
    var onSurfaceTapped: ((SIMD2<Float>) -> Void)? = nil
    /// Drag across the car → shell UV stream (`ended` on release).
    var onSurfaceDragged: ((SIMD2<Float>, _ ended: Bool) -> Void)? = nil
    /// Pinch / two-finger rotate (relative to gesture start, `ended` on release).
    var onPinch: ((Float, _ ended: Bool) -> Void)? = nil
    var onRotate: ((Float, _ ended: Bool) -> Void)? = nil

    @State private var spin: EventSubscription?
    @State private var refs = TurntableRefs()

    var body: some View {
        // These gestures don't exist on tvOS; the customizer only runs
        // on iPad, the TV merely compiles this file.
        #if os(tvOS)
        realityView
        #else
        GeometryReader { geo in
            realityView
                .gesture(SpatialTapGesture().onEnded { value in
                    guard let uv = raycastUV(at: value.location, viewSize: geo.size) else { return }
                    if let onSurfaceTapped {
                        onSurfaceTapped(uv.0)
                    } else if let onPartTapped {
                        onPartTapped(uv.1)
                    }
                })
                .simultaneousGesture(DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard let onSurfaceDragged,
                              let uv = raycastUV(at: value.location, viewSize: geo.size) else { return }
                        onSurfaceDragged(uv.0, false)
                    }
                    .onEnded { value in
                        guard let onSurfaceDragged,
                              let uv = raycastUV(at: value.location, viewSize: geo.size) else { return }
                        onSurfaceDragged(uv.0, true)
                    })
                .simultaneousGesture(MagnifyGesture()
                    .onChanged { onPinch?(Float($0.magnification), false) }
                    .onEnded { onPinch?(Float($0.magnification), true) })
                .simultaneousGesture(RotateGesture()
                    .onChanged { onRotate?(Float($0.rotation.radians), false) }
                    .onEnded { onRotate?(Float($0.rotation.radians), true) })
        }
        #endif
    }

    /// Screen point → (shell UV, hit part name) via camera ray + scene raycast.
    private func raycastUV(at point: CGPoint, viewSize: CGSize) -> (SIMD2<Float>, String)? {
        guard let camera = refs.camera, let car = refs.car, let scene = car.scene,
              viewSize.width > 0, viewSize.height > 0 else { return nil }
        let direction = CameraRay.direction(
            point: point, viewSize: viewSize,
            fovDegrees: camera.camera.fieldOfViewInDegrees,
            cameraTransform: camera.transformMatrix(relativeTo: nil))
        let origin = camera.position(relativeTo: nil)
        guard let hit = scene.raycast(origin: origin, direction: direction,
                                      length: 5, query: .nearest).first,
              let body = PaintShell.bodyEntity(of: car),
              let mesh = body.components[ModelComponent.self]?.mesh else { return nil }
        let local = body.convert(position: hit.position, from: nil)
        let uv = ShellGeometry.projectUV(local, boundsMin: mesh.bounds.min,
                                         boundsMax: mesh.bounds.max)
        return (uv, hit.entity.name)
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
            refs.camera = camera
            let light = DirectionalLight()
            light.light.intensity = 5000
            light.look(at: .zero, from: [1, 2, -2], relativeTo: nil)
            content.add(light)

            await Self.rebuild(turntable, design: design, refs: refs)
            spin = content.subscribe(to: SceneEvents.Update.self) { event in
                turntable.transform.rotation *= simd_quatf(
                    angle: Float(event.deltaTime) * 1.0, axis: [0, 1, 0])
            }
        } update: { content in
            guard let turntable = content.entities.first(where: { $0.name == "turntable" }) else { return }
            Task { @MainActor in
                await Self.rebuild(turntable, design: design, refs: refs)
            }
        }
    }

    @MainActor
    private static func rebuild(_ turntable: Entity, design: CarDesign,
                                refs: TurntableRefs) async {
        let parts = (design.partColors ?? [:]).sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        let livery = design.livery.map {
            "\($0.pattern.rawValue)/\($0.colorHex)/\($0.scale)"
        } ?? "none"
        let stickers = (design.stickers ?? []).map {
            "\($0.symbol)@\($0.uv.x),\($0.uv.y)x\($0.scale)r\($0.rotation)#\($0.colorHex)"
        }.joined(separator: ";")
        let signature = "\(design.chassis.rawValue)|\(design.paint.colorHex)|\(design.paint.finish.rawValue)|\(parts)|\(livery)|\(stickers)|\(design.drawingPNG?.hashValue ?? 0)"
        guard turntable.components[PreviewSignature.self]?.value != signature else { return }
        turntable.components.set(PreviewSignature(value: signature))

        // Same chassis already on the turntable → refresh in place (the
        // overlay swap is cheap; a full reload flickers).
        if let car = refs.car, car.parent === turntable,
           car.name == design.chassis.modelName {
            await CarFactory.applyCustomization(to: car, design: design)
            return
        }

        turntable.children.forEach { $0.removeFromParent() }
        guard let car = try? await AssetStore.shared.entity(named: design.chassis.modelName) else { return }
        car.name = design.chassis.modelName
        await CarFactory.applyCustomization(to: car, design: design)
        // Raycast targets for stamping + paint-slot selection.
        car.generateCollisionShapes(recursive: true)
        let bounds = car.visualBounds(relativeTo: nil)
        car.position = -bounds.center
        turntable.addChild(car)
        refs.car = car
    }
}

/// Entity refs the gesture handlers need (set during scene build).
@MainActor
final class TurntableRefs {
    weak var camera: PerspectiveCamera?
    weak var car: Entity?
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
