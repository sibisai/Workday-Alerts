//
//  TimedNotificationApp.swift
//  TimedNotification
//
//  Created by Sibi on 5/12/25.
//
//  Request notification permission on launch.

import SwiftUI
import UserNotifications

@main
struct WorkdayAlertsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    init() { NotificationManager.shared.requestAuthorization() }

    var body: some Scene {
        WindowGroup { ContentView() }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    // stop looping alarm + clear badge
                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(
                            withIdentifiers: [AlarmIDs.repeatID])
                    UNUserNotificationCenter.current().setBadgeCount(0)
                    HapticManager.shared.stop()

                default:
                    break
                }
            }
    }
}

