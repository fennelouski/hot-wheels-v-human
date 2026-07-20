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

    /// nil = a fresh build. Pass a saved design (the garage's "Edit It") to
    /// edit in place — Save writes back over that car, not to a sibling.
    init(design: CarDesign? = nil, isPlayerTwo: Bool = false) {
        self.isPlayerTwo = isPlayerTwo
        _model = State(initialValue: CustomizerModel(design: design))
    }

    @State private var model: CustomizerModel
    @State private var tab: Tab = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--demo-driver") { return .driver }
        return args.contains("--demo-design") ? .draw : .chassis
    }()
    @State private var saved = false
    @State private var testing = false
    @State private var paintSlot = CarPaintSlot.body
    @State private var armedSticker: String? = nil
    @State private var stickerColor = "#F2F2F7"
    /// Mid-gesture sticker state shown on the turntable; committed to the
    /// design (one undo entry) when the gesture ends.
    @State private var draftStickers: [StickerPlacement]? = nil
    #if canImport(PencilKit) && !os(tvOS)
    /// Session-held pencil strokes (the design only stores the capped PNG).
    @State private var pencilStrokes = PKDrawing()
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
                // Sticker editing only claims the gestures on its own tab.
                // Leaving them claimed everywhere meant a drag on the Paint
                // tab silently dragged your last sticker, and left no gesture
                // free for looking around the car.
                onSurfaceTapped: stickerMode ? armedSticker.map { symbol in
                    { uv in
                        var stickers = model.design.stickers ?? []
                        stickers.append(StickerPlacement(
                            symbol: symbol, uv: ShellGeometry.clampStickerUV(uv),
                            scale: 1, rotation: 0, colorHex: stickerColor))
                        model.design.stickers = stickers
                        SoundBank.shared.play("customize_confirm_pop")
                    }
                } : nil,
                onSurfaceDragged: stickerMode ? { uv, ended in
                    editNewestSticker(ended: ended) { $0.uv = ShellGeometry.clampStickerUV(uv) }
                } : nil,
                onPinch: stickerMode ? { magnification, ended in
                    editNewestSticker(ended: ended) {
                        $0.scale = max(0.3, min(committedNewestSticker?.scale ?? 1, 4) * magnification)
                    }
                } : nil,
                onRotate: stickerMode ? { radians, ended in
                    editNewestSticker(ended: ended) {
                        $0.rotation = (committedNewestSticker?.rotation ?? 0) + radians
                    }
                } : nil
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

            ChipRow(chips: Tab.allCases.map {
                .init(value: $0, title: $0.rawValue, symbol: $0.symbolName)
            }, selection: $tab)
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
                    // Character creation moved to its own experience
                    // (Features/Profiles) — this tab shows who's riding.
                    VStack(spacing: 14) {
                        HStack(spacing: 16) {
                            DriverPreviewView(driver: appModel.raceDriver)
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                            Text(appModel.raceDriver.name)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                        }
                        NavigationLink {
                            CharacterEditorView(driver: appModel.raceDriver)
                        } label: {
                            Label("Edit My Racer", systemImage: "pencil")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 24)
                                .frame(height: 64)
                        }
                        .buttonStyle(.bordered)
                        .tint(.yellow)
                    }
                }
            }
            // No height cap on the tab shelf: tabs aren't the same height
            // (Paint's swatch grid is twice Chassis'), and .frame(maxHeight:)
            // does NOT clip — it just made the taller ones draw straight
            // through the buttons below. Uncapped, the shelf takes what it
            // needs and the turntable above (flexible down to 220) gives up
            // the difference.

            HStack(spacing: 16) {
                // Race the car on the turntable — unsaved paint and all —
                // around whichever track is queued up next.
                TryItButton(title: "Test Drive!") {
                    testing = true
                }
                SaveItButton(saved: saved) {
                    model.save(into: modelContext)
                    if isPlayerTwo {
                        appModel.playerTwoDesign = model.design
                    } else {
                        appModel.selectedDesign = model.design
                    }
                    saved = true
                    SoundBank.shared.play("confirm_sparkle")
                }
            }
            .onChange(of: model.design) { old, _ in
                saved = false
                model.designChanged(from: old)
            }
        }
        .padding(.vertical)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .racePreview(isPresented: $testing,
                     designs: [appModel.stampedRaceDesign(car: model.design)])
    }

    /// Whose gestures these are: the sticker tools' on the Stickers tab,
    /// the camera's everywhere else.
    private var stickerMode: Bool { tab == .stickers }

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
    @State private var refs = OrbitRefs()

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
                    .onChanged { dragged($0, in: geo.size, ended: false) }
                    .onEnded { dragged($0, in: geo.size, ended: true) })
                .simultaneousGesture(MagnifyGesture()
                    .onChanged { pinched($0.magnification, ended: false) }
                    .onEnded { pinched($0.magnification, ended: true) })
                .simultaneousGesture(RotateGesture()
                    .onChanged { onRotate?(Float($0.rotation.radians), false) }
                    .onEnded { onRotate?(Float($0.rotation.radians), true) })
        }
        #endif
    }

    #if !os(tvOS)
    /// The sticker tools own drag and pinch while they're out (the Stickers
    /// tab). Everywhere else the same two gestures steer the camera, so
    /// "look at the other side of my car" works on every tab but that one.
    private func dragged(_ value: DragGesture.Value, in size: CGSize, ended: Bool) {
        if let onSurfaceDragged {
            guard let uv = raycastUV(at: value.location, viewSize: size) else { return }
            onSurfaceDragged(uv.0, ended)
        } else {
            refs.orbit.drag(value.translation, ended: ended)
        }
    }

    private func pinched(_ magnification: CGFloat, ended: Bool) {
        if let onPinch {
            onPinch(Float(magnification), ended)
        } else {
            refs.orbit.pinch(magnification, ended: ended)
        }
    }
    #endif

    /// Screen point → (shell UV, hit part name) via camera ray + scene raycast.
    private func raycastUV(at point: CGPoint, viewSize: CGSize) -> (SIMD2<Float>, String)? {
        guard let camera = refs.camera, let car = refs.model, let scene = car.scene,
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
            refs.frame(camera, target: .zero, from: [0, 0.14, -0.32])
            content.add(camera)
            let light = DirectionalLight()
            light.light.intensity = 5000
            light.look(at: .zero, from: [1, 2, -2], relativeTo: nil)
            content.add(light)

            await Self.rebuild(turntable, design: design, refs: refs)
            spin = content.subscribe(to: SceneEvents.Update.self) { event in
                // Once it's been grabbed the kid is driving: the car freezes
                // where they caught it and the camera does the moving.
                guard !refs.orbit.grabbed else { return refs.apply() }
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
                                refs: OrbitRefs) async {
        let parts = (design.partColors ?? [:]).sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        let livery = design.livery.map {
            "\($0.pattern.rawValue)/\($0.colorHex)/\($0.scale)"
        } ?? "none"
        let stickers = (design.stickers ?? []).map {
            "\($0.symbol)@\($0.uv.x),\($0.uv.y)x\($0.scale)r\($0.rotation)#\($0.colorHex)"
        }.joined(separator: ";")
        let signature = "\(design.modelName)|\(design.paint.colorHex)|\(design.paint.finish.rawValue)|\(parts)|\(livery)|\(stickers)|\(design.drawingPNG?.hashValue ?? 0)"
        guard turntable.components[PreviewSignature.self]?.value != signature else { return }
        turntable.components.set(PreviewSignature(value: signature))

        // Same chassis already on the turntable → refresh in place (the
        // overlay swap is cheap; a full reload flickers).
        if let car = refs.model, car.parent === turntable,
           car.name == design.modelName {
            await CarFactory.applyCustomization(to: car, design: design)
            return
        }

        turntable.children.forEach { $0.removeFromParent() }
        guard let car = try? await AssetStore.shared.entity(named: design.modelName) else { return }
        car.name = design.modelName
        await CarFactory.applyCustomization(to: car, design: design)
        // Raycast targets for stamping + paint-slot selection.
        car.generateCollisionShapes(recursive: true)
        let bounds = car.visualBounds(relativeTo: nil)
        car.position = -bounds.center
        turntable.addChild(car)
        refs.model = car
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
