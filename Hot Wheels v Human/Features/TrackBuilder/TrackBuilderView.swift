//
//  TrackBuilderView.swift
//  Hot Wheels v Human
//
//  2D top-down builder: canvas up top, piece palette below, toolbar of
//  big friendly buttons. No free placement — pieces attach to the open
//  exit with derived orientation, so a kid can't build a broken track.
//

import SwiftUI
import SwiftData

struct TrackBuilderView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext

    @State private var model = TrackBuilderModel()
    @State private var savedName: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Text("🛠️ Track Builder")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                Spacer()
                Text("\(model.types.count) \(model.types.count == 1 ? "piece" : "pieces")")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(String(repeating: "🌶️", count: min(model.difficulty, 5)))
            }
            .padding(.horizontal, 20)

            TrackCanvasView(layout: model.layout)
                .frame(maxHeight: .infinity)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)

            PiecePaletteView(model: model)

            HStack(spacing: 14) {
                toolButton("↩️ Undo") { model.removeLast() }
                toolButton("🗑️ Clear") { model.clear() }
                toolButton("🎲 Shuffle") {
                    model.shuffle()
                    savedName = nil
                }
                Spacer()
                Button {
                    let name = "Track \(Int.random(in: 100...999))"
                    model.save(named: name, into: modelContext, appModel: appModel)
                    savedName = name
                } label: {
                    Text(savedName.map { "✅ \($0) races next!" } ?? "💾 Save & Race This Track")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.isRaceable)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16))
        .foregroundStyle(.white)
        .onChange(of: model.types) { savedName = nil }
    }

    private func toolButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }
}

/// Palette of appendable pieces; impossible appends gray out live.
struct PiecePaletteView: View {
    let model: TrackBuilderModel

    private static let cards: [(PieceType, String, String)] = [
        (.straight, "⬆️", "Straight"),
        (.curve90L, "↰", "Left"),
        (.curve90R, "↱", "Right"),
        (.curveLarge, "⤴️", "Sweeper"),
        (.loop, "➰", "Loop"),
        (.bump, "🐫", "Bump"),
        (.hillUp, "⛰️", "Hill Up"),
        (.hillDown, "🏔️", "Hill Down"),
        (.rampJump, "🛫", "Jump"),
        (.finishGate, "🏁", "Finish"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Self.cards, id: \.0) { type, icon, name in
                    let allowed = model.canAppend(type)
                    Button {
                        model.append(type)
                    } label: {
                        VStack(spacing: 4) {
                            Text(icon).font(.system(size: 40))
                            Text(name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .frame(width: 96, height: 86)
                        .background(.white.opacity(allowed ? 0.12 : 0.04),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .opacity(allowed ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!allowed)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    TrackBuilderView()
        .environment(AppModel())
        .modelContainer(for: [TrackBlueprintRecord.self], inMemory: true)
}
