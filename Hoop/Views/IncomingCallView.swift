import SwiftUI

struct IncomingCallView: View {
    let callService: CallService

    var body: some View {
        if let call = callService.incomingCall {
            HStack(spacing: 16) {
                // Caller info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Incoming Call")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(call.callerName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !call.callerNumber.isEmpty {
                        Text(call.callerNumber)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Decline button
                Button {
                    callService.declineCall()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.red))
                }
                .buttonStyle(.plain)

                // Accept button
                Button {
                    callService.acceptCall()
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.green))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
