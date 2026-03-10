import SwiftUI

struct AirDropIndicatorView: View {
    let airDropService: AirDropService

    var body: some View {
        if let transfer = airDropService.activeTransfer {
            HStack(spacing: 10) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(transfer.direction == .sending ? "Sending via AirDrop" : "Received via AirDrop")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(transfer.fileName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    airDropService.dismissTransfer()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
