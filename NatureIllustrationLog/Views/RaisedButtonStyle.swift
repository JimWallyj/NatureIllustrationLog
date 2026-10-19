import SwiftUI

extension Color {
    /// Deep forest green used by the app's raised buttons.
    static let forestGreen = Color(red: 0.16, green: 0.42, blue: 0.22)
}

/// A solid, raised-looking button so large text buttons can't be mistaken for
/// labels: a top-to-bottom gradient fill, a thin light edge along the top, and
/// a soft shadow underneath. When pressed, the shadow shrinks and the button
/// darkens slightly, so it looks pushed in. Disabled buttons are dimmed.
///
/// Usage: `.buttonStyle(RaisedButtonStyle())`
struct RaisedButtonStyle: ButtonStyle {
    var color: Color = .forestGreen
    var font: Font = .title3.bold()

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        configuration.label
            .font(font)
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background {
                shape.fill(
                    LinearGradient(
                        colors: [
                            color.mix(with: .white, by: 0.18),
                            color.mix(with: .black, by: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                // Light catching the top edge.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0)],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
            }
            .brightness(pressed ? -0.08 : 0)
            .shadow(
                color: .black.opacity(pressed ? 0.15 : 0.35),
                radius: pressed ? 1 : 5,
                x: 0,
                y: pressed ? 1 : 4
            )
            .scaleEffect(pressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

#Preview {
    VStack(spacing: 30) {
        Button("Illustration Projects") {}
            .buttonStyle(RaisedButtonStyle(font: .title2.bold()))
        Button("Change Background") {}
            .buttonStyle(RaisedButtonStyle())
        Button("Disabled") {}
            .buttonStyle(RaisedButtonStyle())
            .disabled(true)
    }
    .padding(40)
}
