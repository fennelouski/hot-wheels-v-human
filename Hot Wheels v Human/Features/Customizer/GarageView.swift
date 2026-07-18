//
//  GarageView.swift
//  Hot Wheels v Human
//
//  Saved designs grid: tap = race this car, hold = delete.
//

import SwiftUI
import SwiftData

struct GarageView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CarDesignRecord.name) private var records: [CarDesignRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                VStack(spacing: 16) {
                    Text("🏚️").font(.system(size: 80))
                    Text("Garage is empty — build a car first!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 20)], spacing: 20) {
                        ForEach(records) { record in
                            garageCard(record)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .navigationTitle("Garage")
    }

    private func garageCard(_ record: CarDesignRecord) -> some View {
        let design = record.design
        let isSelected = appModel.selectedDesign?.id == record.id
        return Button {
            if let design {
                appModel.selectedDesign = design
            }
        } label: {
            VStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: design?.paint.colorHex ?? "#888888"))
                    .frame(width: 54, height: 54)
                    .overlay(Text("🏎️").font(.system(size: 30)))
                Text(record.name)
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
