import SwiftUI

struct NotchRootView: View {
    let state: NotchState

    private var isExpanded: Bool {
        state.phase == .expanding || state.phase == .expanded
    }

    var body: some View {
        GeometryReader { geo in
            let shape = NotchShape(
                cornerRadius: isExpanded ? 20 : 10,
                notchWidth: state.collapsedSize.width,
                notchDepth: isExpanded ? state.collapsedSize.height : 0,
                hasNotch: state.screenHasNotch
            )

            ZStack {
                // Vibrancy layer (expanded) — frosted glass
                VisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    isActive: isExpanded
                )
                .clipShape(shape)
                .opacity(isExpanded ? 1 : 0)

                // Opaque black layer (collapsed) — matches hardware notch
                shape
                    .fill(.black)
                    .opacity(isExpanded ? 0 : 1)

                // Content overlay
                Text("Hoop")
                    .font(isExpanded ? .title3 : .caption)
                    .foregroundStyle(.white)
            }
            .frame(
                width: isExpanded ? geo.size.width : state.collapsedSize.width,
                height: isExpanded ? geo.size.height : state.collapsedSize.height
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
}
