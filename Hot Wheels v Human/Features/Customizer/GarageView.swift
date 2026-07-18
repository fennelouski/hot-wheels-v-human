//
//  GarageView.swift
//  Hot Wheels v Human
//
//  Car grid: starter presets + saved designs. Tap = race this car,
//  hold a saved car = delete. Presets are built-in, not deletable.
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
                sectionHeader("My Cars", systemImage: "car.2.fill")
                if records.isEmpty {
                    Text("Nothing here yet — build a car, or grab a starter below!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(records) { record in
                            carCard(name: record.name, design: record.design,
                                    id: record.id) {
                                if let design = record.design {
                                    select(design)
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    if appModel.selectedDesign?.id == record.id {
                                        appModel.selectedDesign = nil
                                    }
                                    modelContext.delete(record)
                                    try? modelContext.save()
                                } label: {
                                    Label("Scrap it", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                sectionHeader("Starter Cars", systemImage: "sparkles")
                    .padding(.top, 12)
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(CarDesign.presets) { design in
                        carCard(name: design.name, design: design, id: design.id) {
                            select(design)
                        }
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

    private func select(_ design: CarDesign) {
        appModel.selectedDesign = design
        SoundBank.shared.play("car_select_vroom")
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(.yellow)
    }

    private func carCard(name: String, design: CarDesign?, id: UUID,
                         action: @escaping () -> Void) -> some View {
        let isSelected = appModel.selectedDesign?.id == id
        return Button(action: action) {
            VStack(spacing: 10) {
                if let design {
                    CarSwatchView(design: design, size: 54)
                } else {
                    Circle()
                        .fill(Color(hex: "#888888"))
                        .frame(width: 54, height: 54)
                        .overlay(Image(systemName: "car.side.fill").font(.system(size: 26)))
                }
                Text(name)
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
