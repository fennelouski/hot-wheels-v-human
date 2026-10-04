import SwiftUI

struct GameSettingsView: View {
    @State private var preferences = GamePreferences.shared
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Label("Game Feel", systemImage: "slider.horizontal.3")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                setting("Animation", icon: "sparkles", value: $preferences.animationsEnabled,
                        detail: systemReduceMotion ? "Reduce Motion is on for this device." : "World motion, lively buttons and driver camera.")
                setting("Haptics", icon: "hand.tap.fill", value: $preferences.hapticsEnabled,
                        detail: "Tap and boost feedback on supported iPads.")
                Label("Race timing and controls stay the same.", systemImage: "flag.checkered")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.09, green: 0.10, blue: 0.16).ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Settings")
        .accessibilityIdentifier("game-settings")
    }

    private func setting(_ title: String, icon: String, value: Binding<Bool>, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { value.wrappedValue.toggle() } label: {
                HStack(spacing: 18) {
                    Image(systemName: icon).frame(width: 36)
                    Text(title).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Label(value.wrappedValue ? "On" : "Off", systemImage: value.wrappedValue ? "checkmark.circle.fill" : "circle")
                }
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .frame(minHeight: 72)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            #if os(tvOS)
            .buttonStyle(TVWorkshopButtonStyle(selected: value.wrappedValue))
            #else
            .buttonStyle(.plain)
            .foregroundStyle(value.wrappedValue ? Color.black : .white)
            .background(value.wrappedValue ? Color.yellow : .white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
            #endif
            .accessibilityIdentifier(title == "Animation" ? "game-setting-animation" : "game-setting-haptics")
            .accessibilityValue(value.wrappedValue ? "On" : "Off")
            .accessibilityAddTraits(value.wrappedValue ? .isSelected : [])
            Text(detail).font(.system(.body, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 20)
        }
    }
}
