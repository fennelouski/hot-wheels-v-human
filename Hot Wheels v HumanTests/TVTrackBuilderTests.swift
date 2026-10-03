import Foundation
import Testing
import simd
@testable import Hot_Wheels_v_Human

@MainActor
struct TVTrackBuilderTests {
    @Test func blueprintIdentityDoesNotChangeWhenReadingPreview() {
        let model = TrackBuilderModel()
        #expect(model.blueprint.trackId == model.blueprint.trackId)
        let id = model.blueprint.trackId
        model.append(.straight)
        #expect(model.blueprint.trackId == id)
        model.clear()
        #expect(model.blueprint.trackId != id)
    }

    @Test func loadedTrackRestoresEmptyWorldAndClearsHeldSelection() {
        let model = TrackBuilderModel()
        model.placingModel = "taxi"
        model.placeScenery(atX: 1, z: 2)
        model.movingIndex = 0
        var empty = TrackBlueprint.demo
        empty.worldTheme = "city"
        empty.worldEmpty = true
        model.load(preset: empty)
        #expect(model.worldEmpty)
        #expect(model.worldTheme == "city")
        #expect(model.blueprint.worldEmpty == true)
        #expect(model.blueprint.trackId == empty.trackId)
        #expect(model.placingModel == nil)
        #expect(model.movingIndex == nil)
        model.load(preset: .demo)
        #expect(!model.worldEmpty)
    }

    @Test func selectedDecorationRemovalKeepsRemainingIdentitiesAndCoordinates() {
        let model = TrackBuilderModel()
        model.placingModel = "street-straight"
        model.placeScenery(atX: 0, z: 0)
        model.placeScenery(atX: 1.4, z: 0)
        model.placeScenery(atX: 2.8, z: 0)
        let firstID = model.decorationChoices[0].id
        let thirdID = model.decorationChoices[2].id
        model.movingIndex = 1
        model.removePickedScenery()
        #expect(model.scenery.count == 2)
        #expect(model.decorationChoices.map(\.id) == [firstID, thirdID])
        #expect(model.decorationChoices.map(\.index) == [0, 1])
        #expect(abs(model.scenery[1].x - 2.8) < 0.001)
        #expect(model.movingIndex == nil)
    }

    @Test func remoteRotationAndMovementPreserveRoadGridSnapping() {
        let model = TrackBuilderModel()
        model.placingModel = "street-straight"
        model.placeScenery(atX: 0.31, z: 0.72)
        model.movingIndex = 0
        model.rotatePickedScenery()
        #expect(abs(model.scenery[0].yaw - .pi / 2) < 0.001)
        model.moveScenery(atX: 1.02, z: 1.22)
        #expect(abs(model.scenery[0].x - 0.7) < 0.001)
        #expect(abs(model.scenery[0].z - 1.4) < 0.001)
        #expect(model.movingIndex == nil)
    }

    @Test func remotePortalRejectsNonfiniteCoordinatesWithoutLosingPendingExit() {
        let model = TrackBuilderModel()
        model.appendPortal()
        let index = model.placingPortalIndex
        let previous = model.portalExits
        #expect(index != nil)
        #expect(!model.placePortalExit(atX: .infinity, z: 0))
        #expect(model.portalExits == previous)
        #expect(model.placingPortalIndex == index)
        model.cancelPortalPlacement()
        #expect(model.placingPortalIndex == nil)
        #expect(BlueprintValidator.validate(model.blueprint, requireEnding: false).isValid)
    }

    @Test func portalCanBeAddedWhenNearDefaultWouldOverlapAnEarlierSegment() {
        let model = TrackBuilderModel()
        model.append(.curve90L)
        model.append(.straight)
        model.append(.curve90L)
        #expect(model.types == [.startGate, .curve90L, .straight, .curve90L])
        #expect(model.canAppendPortal)
        model.appendPortal()
        #expect(model.placingPortalIndex == 5)
        #expect(model.types.suffix(2) == [.portalIn, .portalOut])
        #expect(BlueprintValidator.validate(model.blueprint, requireEnding: false).isValid)
    }

    @Test func cursorDirectionsFollowCameraAndIncludeSpaceAroundWholeTrack() {
        let controls = TVTrackControls()
        let layout = TrackLayoutSolver.solve(.demo)
        controls.positionCursor(at: .zero, layout: layout)
        controls.nudge(.right, layout: layout)
        #expect(abs(controls.cursor.x - cos(controls.azimuth) * 0.7) < 0.001)
        #expect(abs(controls.cursor.y + sin(controls.azimuth) * 0.7) < 0.001)
        controls.positionCursor(at: SIMD2(100, -100), layout: layout)
        let maxX = layout.pieces.map(\.worldFootprint.maxX).max() ?? 0
        let minZ = layout.pieces.map(\.worldFootprint.minZ).min() ?? 0
        #expect(controls.cursor == SIMD2(maxX + 30, minZ - 30))
        let previous = controls.cursor
        controls.positionCursor(at: SIMD2(.nan, 0), layout: layout)
        #expect(controls.cursor == previous)
    }

    @Test func remoteCanReachDistantExitOfLongValidTrack() {
        let types: [PieceType] = [.startGate] + Array(repeating: .straight, count: 64)
        let blueprint = TrackBlueprint(trackId: UUID(), lanes: 2,
            segments: types.enumerated().map { SegmentSpec(index: $0.offset, type: $0.element) })
        let layout = TrackLayoutSolver.solve(blueprint)
        let controls = TVTrackControls()
        let point = SIMD2<Float>(layout.exitPosition.x + 1, layout.exitPosition.z)
        #expect(point.y > 30)
        controls.positionCursor(at: point, layout: layout)
        #expect(controls.cursor == point)
    }

    @Test func cameraZoomTiltAndResetKeepFiniteUsablePose() {
        let controls = TVTrackControls()
        for _ in 0..<100 { controls.zoomIn(); controls.tiltUp(); controls.panCamera(.left) }
        #expect(controls.zoom == 0.25)
        #expect(controls.elevation == 1.4)
        #expect(abs(controls.pan.x) <= 30 && abs(controls.pan.z) <= 30)
        for _ in 0..<100 { controls.zoomOut(); controls.tiltDown() }
        #expect(controls.zoom == 6)
        #expect(controls.elevation == 0.1)
        controls.resetCamera()
        #expect(controls.zoom == 1)
        #expect(controls.elevation == 0.55)
        #expect(controls.pan == .zero)
    }
}
