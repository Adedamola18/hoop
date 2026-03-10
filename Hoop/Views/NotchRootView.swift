import SwiftUI

struct NotchRootView: View {
    let state: NotchState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.black)

            Text("Hoop")
                .font(.caption)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
