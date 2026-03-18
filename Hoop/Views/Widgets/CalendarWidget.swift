import AppKit
import SwiftUI

struct CalendarWidgetView: View {
    let calendarService: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Upcoming")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }

            if calendarService.upcomingEvents.isEmpty {
                Text("No upcoming events")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 4)
            } else {
                ForEach(calendarService.upcomingEvents) { event in
                    eventRow(event)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    private func eventRow(_ event: CalendarService.UpcomingEvent) -> some View {
        HStack(spacing: 8) {
            // Calendar color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendarColor ?? CGColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)))
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.timeString)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))

                    if event.isHappeningSoon {
                        Text(event.relativeTimeString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.open(URL(string: "ical://")!)
        }
    }
}

// MARK: - Widget Conformance

final class CalendarNotchWidget: NotchWidget {
    let id = "calendar"
    let name = "Calendar"
    let icon = "calendar"
    let size: WidgetSize = .large

    let calendarService: CalendarService

    init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }

    @MainActor
    func makeBody() -> AnyView {
        AnyView(CalendarWidgetView(calendarService: calendarService))
    }
}
