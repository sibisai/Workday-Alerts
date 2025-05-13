//
//  NotificationManager.swift
//  TimedNotification
//
//  Created by Sibi on 5/12/25.
//
//  Handles all notification scheduling & retrieval.


import Foundation
import UserNotifications
import SwiftUI

struct ScheduledAlert: Identifiable {
    let id: String
    let title: String
    let fireDate: Date
}

enum LunchValidation: LocalizedError {
    case tooEarly, tooLate
    var errorDescription: String? {
        switch self {
        case .tooEarly: return "Lunch must start after you have worked at least 1 minute."
        case .tooLate:  return "Lunch must start before 4 h 30 m of work."
        }
    }
}

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private init() {}

    @Published var pending: [ScheduledAlert] = []

    // MARK: Permission
    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: Scheduling
    /// Schedules alerts. Lunch is fixed at 30 minutes.
    /// - Throws: `LunchValidation` if offset outside (0, 4 h 30 m)
    func scheduleAlerts(clockIn: Date,
                         lunchStartOffset: TimeInterval) async throws {
        guard lunchStartOffset > 0 else { throw LunchValidation.tooEarly }
        guard lunchStartOffset < 4.5 * 3600 else { throw LunchValidation.tooLate }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let lunchDuration: TimeInterval = 30 * 60 // 30 min unpaid

        let events: [(String, Date)] = [
            ("Clock‑out for lunch", clockIn.addingTimeInterval(lunchStartOffset)),
            ("Clock‑in after lunch", clockIn.addingTimeInterval(lunchStartOffset + lunchDuration)),
            ("Clock‑out for the day", clockIn.addingTimeInterval(8.5 * 3600)) // end of 8 h paid + 30 m lunch
        ]

        for (title, date) in events {
            try? await schedule(title: title, fire: date)
            try? await schedule(title: "⏰ 2‑minute warning: \(title.lowercased())", fire: date.addingTimeInterval(-120))
        }

        await refreshPending()
    }

    private func schedule(title: String, fire: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = UNNotificationSound(named: .init("alarm.caf"))
        content.badge = 1
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }

        // 1️⃣ initial one-shot alert
        let mainID     = UUID().uuidString
        let dateComps  = Calendar.current.dateComponents(
            [.year,.month,.day,.hour,.minute,.second], from: fire)

        let dateTrig   = UNCalendarNotificationTrigger(dateMatching: dateComps,
                                                       repeats: false)
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: AlarmIDs.main(mainID),
                                  content: content,
                                  trigger: dateTrig))

        // 2️⃣ repeat every 60 s until we cancel
        let repeatTrig = UNTimeIntervalNotificationTrigger(timeInterval: 60,
                                                           repeats: true)
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: AlarmIDs.repeatID,
                                  content: content,
                                  trigger: repeatTrig))
    }

    // MARK: Fetch
    func refreshPending() async {
        let reqs = await UNUserNotificationCenter.current().pendingNotificationRequests()
        pending = reqs.compactMap { r in
            guard let t = r.trigger as? UNCalendarNotificationTrigger,
                  let d = Calendar.current.date(from: t.dateComponents) else { return nil }
            return ScheduledAlert(id: r.identifier, title: r.content.title, fireDate: d)
        }.sorted { $0.fireDate < $1.fireDate }
    }
}
