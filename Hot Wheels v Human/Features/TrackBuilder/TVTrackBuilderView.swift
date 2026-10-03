#if os(tvOS)
import SwiftUI
import SwiftData

/// The TV uses the same builder model and 3D world as iPad. An inspector
/// replaces hit testing, dragging and pinch with remote-native controls.
struct TVTrackBuilderView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case pieces = "Pieces", decorations = "Decorate", worlds = "Worlds"
        case camera = "Camera", library = "Library"
        var id: Self { self }
        var symbol: String {
            switch self {
            case .pieces: "wrench.and.screwdriver.fill"
            case .decorations: "paintbrush.fill"
            case .worlds: "globe.americas.fill"
            case .camera: "viewfinder"
            case .library: "books.vertical.fill"
            }
        }
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackBlueprintRecord.name) private var savedRecords: [TrackBlueprintRecord]
    @State private var model = TrackBuilderModel()
    @State private var controls = TVTrackControls()
    @State private var section = Section.pieces
    @State private var decorGroup = "Streets"
    @State private var trackName = ""
    @State private var savedBlueprint: TrackBlueprint?
    @State private var message: String?
    @State private var error: String?
    @State private var previewing = false
    @State private var mapExpanded = false
    @State private var movingCursor = false
    @State private var clearing = false
    @State private var deletingRecord: TrackBlueprintRecord?
    @FocusState private var cursorFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    private let pieces: [(PieceType, String)] = [
        (.straight, "Straight"), (.curve90L, "Left"), (.curve90R, "Right"),
        (.curveLarge, "Sweeper"), (.loop, "Loop"), (.bump, "Bump"),
        (.hillUp, "Hill Up"), (.hillDown, "Hill Down"), (.rampJump, "Jump"),
        (.finishGate, "Finish")
    ]

    var body: some View {
        VStack(spacing: 20) {
            header
            GeometryReader { geometry in
                HStack(spacing: 24) {
                    scene
                        .frame(width: max(0, (geometry.size.width - 24) * 0.60))
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if movingCursor {
                                cursorControl
                            } else if model.placingPortalIndex != nil {
                                portalInspector
                            } else {
                                inspector
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .focusSection()
                }
            }
            footer
        }
        .padding(24)
        .background(Color(red: 0.09, green: 0.10, blue: 0.16).ignoresSafeArea())
        .foregroundStyle(.white)
        .onChange(of: model.types.count) { _, count in
            if let index = controls.selectedPiece, index >= count { controls.selectedPiece = nil }
        }
        .alert("Clear this track?", isPresented: $clearing) {
            Button("Keep building", role: .cancel) { }
            Button("Clear", role: .destructive, action: clearTrack)
        } message: {
            Text("Saved tracks stay in your library.")
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "Try again.") }
        .alert("Remove saved track?", isPresented: Binding(
            get: { deletingRecord != nil }, set: { if !$0 { deletingRecord = nil } })) {
            Button("Keep it", role: .cancel) { deletingRecord = nil }
            Button("Remove", role: .destructive, action: deleteSavedTrack)
        } message: { Text(deletingRecord?.name ?? "") }
        .racePreview(isPresented: $previewing,
                     designs: [appModel.stampedRaceDesign()], blueprint: model.blueprint)
        .accessibilityIdentifier("tvTrackBuilder")
    }

    private var header: some View {
        HStack(spacing: 24) {
            Label("Track Builder", systemImage: "wrench.and.screwdriver.fill")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
            Text("\(model.types.count) pieces")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
            Spacer(minLength: 12)
            ForEach(Section.allCases) { item in
                Button { selectSection(item) } label: {
                    Label(item.rawValue, systemImage: item.symbol)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14).frame(minHeight: 64)
                }
                .buttonStyle(TVWorkshopButtonStyle(selected: section == item))
                .accessibilityAddTraits(section == item ? .isSelected : [])
                .accessibilityIdentifier("tvTrackSection-\(item.rawValue)")
            }
        }
        .focusSection()
    }

    private var scene: some View {
        TrackBuilder3DView(model: model, remote: controls)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(alignment: .topTrailing) {
                Button { mapExpanded.toggle() } label: {
                    VStack(spacing: 8) {
                        TrackCanvasView(layout: model.layout, isThumbnail: !mapExpanded)
                            .frame(width: mapExpanded ? 400 : 200, height: mapExpanded ? 260 : 100)
                        Label(mapExpanded ? "Shrink map" : "Enlarge map", systemImage: "map.fill")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .padding(12)
                }
                .buttonStyle(TVWorkshopButtonStyle())
                .padding(16)
                .accessibilityIdentifier("tvTrackMap")
            }
            .overlay(alignment: .bottomLeading) {
                if let message {
                    Text(message)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .padding(16)
                        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                        .padding(16)
                        .accessibilityIdentifier("tvTrackStatus")
                }
            }
    }

    @ViewBuilder private var inspector: some View {
        switch section {
        case .pieces: pieceInspector
        case .decorations: decorationInspector
        case .worlds: worldInspector
        case .camera: cameraInspector
        case .library: libraryInspector
        }
    }

    private var pieceInspector: some View {
        VStack(alignment: .leading, spacing: 24) {
            title("Snap on a piece")
            Button {
                model.placingGhost.toggle()
            } label: {
                Label(model.placingGhost ? "Ghost pieces: On" : "Ghost pieces: Off",
                      systemImage: model.placingGhost ? "checkmark.circle.fill" : "circle.dashed")
                    .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            }
            .buttonStyle(TVWorkshopButtonStyle(selected: model.placingGhost))
            .accessibilityIdentifier("tvTrackGhostMode")
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(pieces, id: \.0) { type, name in
                    action(name, symbol: type.symbolName ?? "arrow.up", id: "tvTrackAppend-\(type.rawValue)") {
                        model.append(type)
                        controls.selectedPiece = model.types.count - 1
                        message = nil
                    }
                    .disabled(!model.canAppend(type))
                }
                action("Portal", symbol: "circle.circle", id: "tvTrackAppendPortal", action: appendPortal)
                    .disabled(!model.canAppendPortal)
            }
            if model.hasFinish {
                Text("Finish placed. Undo it to add more.")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }
            title("Pieces on your track")
            ForEach(model.blueprint.segments, id: \.index) { segment in
                Button { controls.selectedPiece = segment.index } label: {
                    HStack(spacing: 12) {
                        Image(systemName: segment.type.symbolName ?? "arrow.up")
                        Text("\(segment.index + 1). \(pieceName(segment.type))")
                        Spacer()
                        if segment.isGhost == true { Image(systemName: "circle.dashed") }
                        if controls.selectedPiece == segment.index { Image(systemName: "checkmark") }
                    }
                    .padding(.horizontal, 16).frame(minHeight: 64)
                }
                .buttonStyle(TVWorkshopButtonStyle(selected: controls.selectedPiece == segment.index))
                .accessibilityIdentifier("tvTrackPiece-\(segment.index)")
            }
            if let index = controls.selectedPiece, model.types.indices.contains(index) {
                action(model.ghostIndices.contains(index) ? "Make solid" : "Make ghost",
                       symbol: "circle.dashed", id: "tvTrackSelectedGhost") {
                    model.toggleGhost(at: index)
                }
                if model.types[index] == .portalOut {
                    action("Move portal exit", symbol: "move.3d", id: "tvTrackMovePortal") {
                        model.pickPortalExit(at: index)
                        setCursorToPendingPortal()
                    }
                }
            }
        }
    }

    private var decorationInspector: some View {
        VStack(alignment: .leading, spacing: 24) {
            if model.placingModel != nil || model.movingIndex != nil {
                title(selectedDecorationName)
                if let prop = selectedDecorationModel {
                    DecorPaletteView.thumb(prop).resizable().scaledToFit()
                        .frame(maxWidth: .infinity).frame(height: 120)
                        .accessibilityHidden(true)
                }
                placementControls
                if model.movingIndex != nil {
                    action("Rotate quarter turn", symbol: "rotate.right", id: "tvTrackRotateDecoration") {
                        model.rotatePickedScenery()
                    }
                    action("Remove selected", symbol: "trash", id: "tvTrackRemoveDecoration") {
                        model.removePickedScenery()
                        message = "Decoration removed"
                    }
                }
            } else {
                title("Decoration box")
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(DecorPaletteView.groups, id: \.0) { group in
                            Button { decorGroup = group.0 } label: {
                                Label(group.0, systemImage: group.1)
                                    .padding(.horizontal, 16).frame(minHeight: 64)
                            }
                            .buttonStyle(TVWorkshopButtonStyle(selected: decorGroup == group.0))
                        }
                    }
                    .padding(4)
                }
                .focusSection()
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(selectedDecorationModels, id: \.self) { prop in
                        Button { selectDecoration(prop) } label: {
                            VStack(spacing: 8) {
                                DecorPaletteView.thumb(prop).resizable().scaledToFit().frame(height: 88)
                                Text(decorationName(prop))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TVWorkshopButtonStyle())
                        .accessibilityIdentifier("tvTrackDecoration-\(prop)")
                    }
                }
                title("Placed decorations")
                if model.scenery.isEmpty {
                    Text("Choose one above, then place it at the yellow target.")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                ForEach(model.decorationChoices) { choice in
                    Button { pickDecoration(choice.index) } label: {
                        HStack(spacing: 12) {
                            DecorPaletteView.thumb(choice.item.model).resizable().scaledToFit().frame(width: 60, height: 60)
                            Text("\(choice.index + 1). \(decorationName(choice.item.model))")
                        }
                        .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    }
                    .buttonStyle(TVWorkshopButtonStyle())
                    .accessibilityIdentifier("tvTrackPlacedDecoration-\(choice.index)")
                }
                action("Undo decoration", symbol: "arrow.uturn.backward", id: "tvTrackUndoDecoration") {
                    model.removeLastScenery()
                }
                .disabled(model.scenery.isEmpty)
            }
        }
    }

    private var selectedDecorationModel: String? {
        if let index = model.movingIndex, model.scenery.indices.contains(index) {
            return model.scenery[index].model
        }
        return model.placingModel
    }

    private var selectedDecorationName: String {
        selectedDecorationModel.map(decorationName) ?? "Decoration"
    }

    private var selectedDecorationModels: [String] {
        DecorPaletteView.groups.first(where: { $0.0 == decorGroup })?.2 ?? []
    }

    private var worldInspector: some View {
        VStack(alignment: .leading, spacing: 24) {
            title("Pick a world")
            Button { model.toggleWorldEmpty() } label: {
                Label(model.worldEmpty ? "Empty world: On" : "Empty world: Off",
                      systemImage: model.worldEmpty ? "checkmark.square.fill" : "square.dashed")
                    .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            }
            .buttonStyle(TVWorkshopButtonStyle(selected: model.worldEmpty))
            .accessibilityIdentifier("tvTrackEmptyWorld")
            Button { model.selectWorld(nil) } label: {
                Label("Surprise", systemImage: "sparkles")
                    .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            }
                .buttonStyle(TVWorkshopButtonStyle(selected: model.worldTheme == nil))
                .accessibilityIdentifier("tvTrackWorld-auto")
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(ArenaEnvironment.themes, id: \.name) { theme in
                    Button { model.selectWorld(theme.name) } label: {
                        Label(theme.displayName, systemImage: theme.symbol)
                            .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(TVWorkshopButtonStyle(selected: model.worldTheme == theme.name))
                    .accessibilityIdentifier("tvTrackWorld-\(theme.name)")
                }
            }
        }
    }

    private var cameraInspector: some View {
        VStack(alignment: .leading, spacing: 24) {
            title("Look around")
            LazyVGrid(columns: columns, spacing: 16) {
                action("Orbit left", symbol: "rotate.left", id: "tvTrackOrbitLeft", action: controls.orbitLeft)
                action("Orbit right", symbol: "rotate.right", id: "tvTrackOrbitRight", action: controls.orbitRight)
                action("Look higher", symbol: "arrow.up", id: "tvTrackTiltUp", action: controls.tiltUp)
                action("Look lower", symbol: "arrow.down", id: "tvTrackTiltDown", action: controls.tiltDown)
                action("Zoom in", symbol: "plus.magnifyingglass", id: "tvTrackZoomIn", action: controls.zoomIn)
                action("Zoom out", symbol: "minus.magnifyingglass", id: "tvTrackZoomOut", action: controls.zoomOut)
                action("Pan left", symbol: "arrow.left", id: "tvTrackPanLeft") { controls.panCamera(.left) }
                action("Pan right", symbol: "arrow.right", id: "tvTrackPanRight") { controls.panCamera(.right) }
                action("Pan forward", symbol: "arrow.up", id: "tvTrackPanForward") { controls.panCamera(.forward) }
                action("Pan back", symbol: "arrow.down", id: "tvTrackPanBackward") { controls.panCamera(.backward) }
            }
            action("Fit track", symbol: "arrow.up.left.and.arrow.down.right", id: "tvTrackResetCamera", action: controls.resetCamera)
            action("Show target", symbol: "scope", id: "tvTrackShowTarget") {
                controls.aimAtCursor(layout: model.layout)
            }
        }
    }

    private var libraryInspector: some View {
        VStack(alignment: .leading, spacing: 24) {
            title("Your library")
            TextField("Name your next saved copy", text: $trackName)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("tvTrackName")
            action("Save a copy", symbol: "bookmark.fill", id: "tvTrackLibrarySave", action: saveTrack)
                .disabled(!model.isRaceable || model.placingPortalIndex != nil)
            if savedRecords.isEmpty {
                Text("Save a finished track here. You can keep building after a race.")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }
            ForEach(savedRecords) { record in
                if let blueprint = record.blueprint {
                    Button { loadTrack(blueprint, name: record.name) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(record.name).font(.system(size: 25, weight: .bold, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                            TrackCanvasView(layout: TrackLayoutSolver.solve(blueprint), isThumbnail: true)
                                .frame(height: 100)
                            Label("Load track", systemImage: "arrow.down.doc")
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(TVWorkshopButtonStyle())
                    .accessibilityIdentifier("tvTrackLoad-\(record.id.uuidString)")
                    action("Remove \(record.name)", symbol: "trash", id: "tvTrackDelete-\(record.id.uuidString)") {
                        deletingRecord = record
                    }
                }
            }
            title("Starter tracks")
            ForEach(TrackBlueprint.presets, id: \.blueprint.trackId) { preset in
                Button { loadTrack(preset.blueprint, name: preset.name) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(preset.name).font(.system(size: 25, weight: .bold, design: .rounded))
                        TrackCanvasView(layout: TrackLayoutSolver.solve(preset.blueprint), isThumbnail: true)
                            .frame(height: 100)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(TVWorkshopButtonStyle())
                .accessibilityIdentifier("tvTrackPreset-\(preset.blueprint.trackId.uuidString)")
            }
        }
    }

    private var portalInspector: some View {
        VStack(alignment: .leading, spacing: 24) {
            title("Place portal exit")
            placementControls
            action("Keep current exit", symbol: "checkmark", id: "tvTrackCancelPortal") {
                model.cancelPortalPlacement()
                movingCursor = false
                message = nil
            }
        }
    }

    private var placementControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.movingIndex != nil ? "Move selected decoration" : "Yellow target")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            action("Move with remote", symbol: "dpad", id: "tvTrackMoveCursor") {
                movingCursor = true
            }
            action("Place here", symbol: "plus.circle.fill", id: "tvTrackPlace", action: placeAtCursor)
            LazyVGrid(columns: columns, spacing: 16) {
                action("Left", symbol: "arrow.left", id: "tvTrackCursorLeft") { nudge(.left) }
                action("Right", symbol: "arrow.right", id: "tvTrackCursorRight") { nudge(.right) }
                action("Forward", symbol: "arrow.up", id: "tvTrackCursorForward") { nudge(.forward) }
                action("Back", symbol: "arrow.down", id: "tvTrackCursorBackward") { nudge(.backward) }
            }
            Button { controls.fineStep.toggle() } label: {
                Label(controls.fineStep ? "Small steps" : "Large steps",
                      systemImage: controls.fineStep ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            }
            .buttonStyle(TVWorkshopButtonStyle(selected: controls.fineStep))
            .accessibilityIdentifier("tvTrackCursorStep")
            if model.movingIndex != nil || model.placingModel != nil {
                action(model.movingIndex != nil ? "Done" : "Back to box",
                       symbol: "checkmark", id: "tvTrackCancelDecoration") {
                    model.placingModel = nil
                    model.movingIndex = nil
                    movingCursor = false
                }
            }
        }
    }

    private var cursorControl: some View {
        VStack(alignment: .leading, spacing: 24) {
            title("Move the yellow target")
            Text("Swipe to move. Select to place. Back to stop.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: placeAtCursor) {
                Label("Place here", systemImage: "scope")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
            .buttonStyle(TVWorkshopButtonStyle(selected: true))
            .focused($cursorFocused)
            .onMoveCommand { direction in
                switch direction {
                case .left: nudge(.left)
                case .right: nudge(.right)
                case .up: nudge(.forward)
                case .down: nudge(.backward)
                @unknown default: break
                }
            }
            .onExitCommand { movingCursor = false }
            .accessibilityIdentifier("tvTrackRemoteCursor")
        }
        .defaultFocus($cursorFocused, true)
    }

    private var footer: some View {
        HStack(spacing: 20) {
            action("Undo", symbol: "arrow.uturn.backward", id: "tvTrackUndo") {
                model.removeLast()
                controls.selectedPiece = model.types.count - 1
                movingCursor = false
            }
            .disabled(model.types.count <= 1)
            action("Clear", symbol: "trash", id: "tvTrackClear") { clearing = true }
            action("Shuffle", symbol: "dice.fill", id: "tvTrackShuffle") {
                model.shuffle()
                controls.selectedPiece = nil
                controls.resetCamera()
                movingCursor = false
                message = "New track ready"
            }
            Spacer(minLength: 12)
            if savedBlueprint == model.blueprint {
                Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.yellow)
            }
            action("Save a copy", symbol: "bookmark.fill", id: "tvTrackSave", action: saveTrack)
                .disabled(!model.isRaceable || model.placingPortalIndex != nil)
            Button { previewing = true } label: {
                Label("Race it!", systemImage: "flag.checkered")
                    .padding(.horizontal, 20).frame(minHeight: 64)
            }
                .buttonStyle(TVWorkshopButtonStyle(selected: true))
                .disabled(!model.isRaceable || model.placingPortalIndex != nil)
                .accessibilityIdentifier("tvTrackRace")
        }
        .font(.system(size: 25, weight: .heavy, design: .rounded))
        .focusSection()
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 32, weight: .heavy, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func action(_ text: String, symbol: String, id: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(text, systemImage: symbol)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
        .buttonStyle(TVWorkshopButtonStyle())
        .accessibilityIdentifier(id)
    }

    private func selectSection(_ next: Section) {
        section = next
        movingCursor = false
        model.decorating = next == .decorations
        if !model.decorating {
            model.placingModel = nil
            model.movingIndex = nil
        }
    }

    private func appendPortal() {
        model.appendPortal()
        controls.selectedPiece = model.types.count - 1
        setCursorToPendingPortal()
        message = "Place the exit at the yellow target"
    }

    private func setCursorToPendingPortal() {
        if let index = model.placingPortalIndex, let point = model.portalExits[index] {
            controls.positionCursor(at: point, layout: model.layout)
        }
    }

    private func selectDecoration(_ prop: String) {
        model.movingIndex = nil
        model.placingModel = prop
        let exit = model.layout.exitPosition
        controls.positionCursor(at: SIMD2(exit.x + 1, exit.z), layout: model.layout)
        message = "\(decorationName(prop)): place at the yellow target"
    }

    private func pickDecoration(_ index: Int) {
        guard model.scenery.indices.contains(index) else { return }
        model.placingModel = nil
        model.movingIndex = index
        let item = model.scenery[index]
        controls.positionCursor(at: SIMD2(item.x, item.z), layout: model.layout)
        message = "Selected \(decorationName(item.model))"
    }

    private func nudge(_ direction: TVTrackControls.Direction) {
        controls.nudge(direction, layout: model.layout)
    }

    private func placeAtCursor() {
        let point = controls.cursor
        if model.placingPortalIndex != nil {
            guard model.placePortalExit(atX: point.x, z: point.y) else {
                message = "That exit overlaps the track. Move the target and try again."
                return
            }
            message = "Portal exit placed"
        } else if model.movingIndex != nil {
            model.moveScenery(atX: point.x, z: point.y)
            message = "Decoration moved"
        } else if model.placingModel != nil {
            guard model.scenery.count < RaceTuning.maxSceneryItems else {
                message = "Decoration box full. Remove one to make room."
                return
            }
            model.placeScenery(atX: point.x, z: point.y)
            model.placingModel = nil
            model.movingIndex = model.scenery.count - 1
            message = "Decoration placed"
        }
        movingCursor = false
    }

    private func loadTrack(_ blueprint: TrackBlueprint, name: String) {
        model.load(preset: blueprint)
        controls.selectedPiece = nil
        controls.resetCamera()
        movingCursor = false
        savedBlueprint = nil
        trackName = name
        message = "Loaded \(name)"
    }

    private func saveTrack() {
        let entered = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = entered.isEmpty ? "Track \(savedRecords.count + 1)" : entered
        guard model.save(named: name, into: modelContext, appModel: appModel) else {
            error = "Your track is still here. Try saving again."
            return
        }
        savedBlueprint = model.blueprint
        message = "Saved \(name)"
    }

    private func clearTrack() {
        model.clear()
        controls.selectedPiece = nil
        controls.resetCamera()
        movingCursor = false
        savedBlueprint = nil
        message = nil
    }

    private func deleteSavedTrack() {
        guard let record = deletingRecord else { return }
        // An unsuccessful deletion must restore the library entry. The
        // current on-screen draft is independent of this saved record.
        modelContext.delete(record)
        do { try modelContext.save() }
        catch {
            modelContext.rollback()
            self.error = "The saved track couldn't be removed. Try again."
        }
        deletingRecord = nil
    }

    private func pieceName(_ type: PieceType) -> String {
        switch type {
        case .startGate: "Start"
        case .portalIn: "Portal entry"
        case .portalOut: "Portal exit"
        default: pieces.first(where: { $0.0 == type })?.1 ?? type.rawValue
        }
    }

    private func decorationName(_ model: String) -> String {
        model.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
#endif
