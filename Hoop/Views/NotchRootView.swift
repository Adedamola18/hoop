import SwiftUI

struct NotchRootView: View {
    let state: NotchState

    private var isExpanded: Bool {
        state.phase == .expanding || state.phase == .expanded
    }

    var body: some View {
        GeometryReader { geo in
            NotchShape(
                cornerRadius: isExpanded ? 20 : 10,
                notchWidth: state.collapsedSize.width,
                notchDepth: isExpanded ? state.collapsedSize.height : 0,
                hasNotch: state.screenHasNotch
            )
            .fill(.black)
            .overlay {
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
