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
            try? await schedule(title: title, fire: date,       withLoops: true)   // real alarm
            try? await schedule(title: "⏰ 2-minute warning: \(title.lowercased())",
                                fire: date.addingTimeInterval(-120),
                                withLoops: false)                                  // no loops
        }
        
        await refreshPending()
    }
    
    // MARK: Scheduling helpers
    private func schedule(title: String,
                          fire start: Date,
                          withLoops addLoops: Bool) async throws {
        let center  = UNUserNotificationCenter.current()
        let sound   = UNNotificationSound(named: .init("alarm.caf"))

        func makeContent(loop: Bool) -> UNMutableNotificationContent {
            let c = UNMutableNotificationContent()
            c.title = title
            c.sound = sound
            c.badge = 1
            if #available(iOS 15.0, *) { c.interruptionLevel = .timeSensitive }
            c.userInfo["loop"] = loop            // tag follow-ups
            return c
        }

        // main one-shot
        let id   = AlarmIDs.main(UUID().uuidString)
        let comps = Calendar.current.dateComponents(
            [.year,.month,.day,.hour,.minute,.second], from: start)

        try await center.add(
            UNNotificationRequest(identifier: id,
                                  content: makeContent(loop: false),
                                  trigger: UNCalendarNotificationTrigger(
                                      dateMatching: comps, repeats: false)))

        // optional loop (only for real alerts, not warnings)
        if addLoops {
            for n in 1...10 {
                let t   = start.addingTimeInterval(Double(n) * 60)
                let dc  = Calendar.current.dateComponents(
                    [.year,.month,.day,.hour,.minute,.second], from: t)
                try await center.add(
                    UNNotificationRequest(identifier: AlarmIDs.main("\(id)-\(n)"),
                                          content: makeContent(loop: true),
                                          trigger: UNCalendarNotificationTrigger(
                                              dateMatching: dc, repeats: false)))
            }
        }
    }
    
    /// Drop past requests and rebuild `pending`
    func purgeObsoleteAndRefresh() async {
        let center = UNUserNotificationCenter.current()
        let now    = Date()

        let obsolete = (await center.pendingNotificationRequests())
            .compactMap { req -> String? in
                guard
                    let trig = req.trigger as? UNCalendarNotificationTrigger,
                    let fire = Calendar.current.date(from: trig.dateComponents),
                    fire < now
                else { return nil }
                return req.identifier
            }

        center.removePendingNotificationRequests(withIdentifiers: obsolete)
        await refreshPending()
    }
    
    // MARK: Fetch (updates upcoming list)
    func refreshPending() async {
        let now   = Date()
        let reqs  = await UNUserNotificationCenter.current()
                        .pendingNotificationRequests()

        pending = reqs.compactMap { req -> ScheduledAlert? in
            // skip time-interval triggers and follow-up loops
            guard
                req.content.userInfo["loop"] as? Bool != true,          // hide loops
                let trig = req.trigger as? UNCalendarNotificationTrigger,
                let fire = Calendar.current.date(from: trig.dateComponents),
                fire > now                                              // hide past
            else { return nil }

            return ScheduledAlert(id: req.identifier,
                                  title: req.content.title,
                                  fireDate: fire)
        }
        .sorted { $0.fireDate < $1.fireDate }
    }
}
