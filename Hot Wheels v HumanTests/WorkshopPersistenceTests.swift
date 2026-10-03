import Foundation
import SwiftData
import Testing
@testable import Hot_Wheels_v_Human

@MainActor
struct WorkshopPersistenceTests {
    @Test func failedCarEncodingPreservesSavedCarAndUnrelatedDraft() throws {
        let container = try ModelContainer(for: CarDesignRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let editor = CustomizerModel(design: CarDesign.presets[0])
        #expect(editor.save(into: context))
        let original = try #require(context.carRecord(editor.design.id)?.design)
        let unrelated = try CarDesignRecord(design: CarDesign.presets[1])
        context.insert(unrelated)
        unrelated.name = "Unrelated unsaved edit"
        editor.design.name = "Draft stays open"
        editor.design.livery = LiverySpec(pattern: .flames, colorHex: "#FFD500", scale: .nan)

        #expect(!editor.save(into: context))
        #expect(editor.lastSaveError != nil)
        #expect(context.carRecord(original.id)?.design == original)
        #expect(unrelated.name == "Unrelated unsaved edit")
        #expect(editor.design.name == "Draft stays open")
    }

    @Test func savingSelectedRacerCommitsLastUsedWithAppearance() throws {
        let container = try ModelContainer(for: DriverProfileRecord.self, KidProfileRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let owner = try KidProfileRecord(profile: KidProfile(id: UUID(), name: "Player", colorHex: "#FFD500"))
        context.insert(owner)
        try context.save()
        let editor = CharacterEditorModel(driver: DriverProfile.presets[0])
        editor.driver.name = "My TV Racer"

        #expect(editor.save(into: context, ownerProfileID: owner.id, rememberAsLastUsed: true))
        #expect(editor.lastSaveError == nil)
        #expect(owner.lastUsedDriverID == editor.driver.id)
        let records = try context.fetch(FetchDescriptor<DriverProfileRecord>())
        #expect(records.count == 1)
        #expect(records.first?.profile?.name == "My TV Racer")
        #expect(records.first?.ownerProfileID == owner.id)
    }
}
