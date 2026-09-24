import SwiftUI

struct RootView: View {
    @Environment(BatchStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Group {
            switch store.step {
            case .builder: BuilderScreen()
            case .preparing: PreparingBatchView()
            case .rename: RenameScreen()
            }
        }
        .frame(minWidth: 720, minHeight: 380)
        .ignoresSafeArea(.container, edges: .top)
        .alert(
            "Can't Rename",
            isPresented: Binding(
                get: { store.renameError != nil },
                set: { presented in
                    if !presented {
                        store.renameError = nil
                        store.focusRequest += 1 // back to typing without a click
                    }
                }
            )
        ) {
            Button("OK") {}
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(store.renameError?.message ?? "")
        }
    }
}

// MARK: - Shared window chrome

/// The 52pt glass header under the (hidden) titlebar. Traffic lights float over
/// its leading edge, so content starts after them.
struct WindowHeader<Leading: View, Trailing: View>: View {
    var title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            leading
            Spacer()
            trailing
        }
        .padding(.leading, 84) // clear of the traffic lights
        .padding(.trailing, 14)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .center) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) { Divider() }
        .gesture(WindowDragGesture())
    }
}

// MARK: - Button styles (from the design's glass-btn / primary-btn)

struct GlassButtonStyle: ButtonStyle {
    var width: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, width == nil ? 12 : 0)
            .frame(width: width, height: 26)
            .background(
                Color.gray.opacity(configuration.isPressed ? 0.3 : 0.17),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 28)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.23, green: 0.63, blue: 1.0), .accentColor],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Small shared pieces

/// Video thumbnail with the design's striped placeholder while loading.
struct ThumbnailView: View {
    var image: CGImage?
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                StripedPlaceholder()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

struct StripedPlaceholder: View {
    var body: some View {
        Canvas { context, size in
            let stripe: CGFloat = 4
            context.rotate(by: .degrees(45))
            var x: CGFloat = -size.height * 2
            while x < size.width + size.height * 2 {
                context.fill(
                    Path(CGRect(x: x, y: -size.height * 2, width: stripe, height: size.width + size.height * 4)),
                    with: .color(.primary.opacity(0.05))
                )
                x += stripe * 2
            }
        }
    }
}
