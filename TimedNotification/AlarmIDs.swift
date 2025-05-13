//
//  AlarmIDs.swift
//  TimedNotification
//
//  Created by Sibi on 5/12/25.
//
// Identifiers we reuse across files so we can cancel the repeating alarm.

enum AlarmIDs {
    static func main(_ id: String) -> String { id }   // unique per event
    static let repeatID = "repeatAlarm"               // constant for the loop
}
