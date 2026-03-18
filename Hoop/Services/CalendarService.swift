import EventKit
import Foundation
import Observation

@Observable
final class CalendarService {

    struct UpcomingEvent: Identifiable {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
        let calendarColor: CGColor?
        let calendarTitle: String

        var isHappeningSoon: Bool {
            startDate.timeIntervalSinceNow < 900 && startDate.timeIntervalSinceNow > 0
        }

        var relativeTimeString: String {
            let minutes = Int(startDate.timeIntervalSinceNow / 60)
            if minutes <= 0 { return "Now" }
            if minutes == 1 { return "In 1 min" }
            if minutes < 60 { return "In \(minutes) min" }
            let hours = minutes / 60
            if hours == 1 { return "In 1 hr" }
            return "In \(hours) hrs"
        }

        var timeString: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: startDate)
        }
    }

    var upcomingEvents: [UpcomingEvent] = []
    var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    func requestAccessAndStart() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted {
                    self?.refreshEvents()
                    self?.startPolling()
                }
            }
        }
    }

    func stopObserving() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshEvents()
        }
    }

    private func refreshEvents() {
        let now = Date()
        let endOfDay = Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now

        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)

        upcomingEvents = ekEvents.map { event in
            UpcomingEvent(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarColor: event.calendar.cgColor,
                calendarTitle: event.calendar.title
            )
        }
    }
}
