//
//  ContentView.swift
//  TimedNotification
//
//  Created by Sibi on 5/12/25.
//
//  Simple UI: pick a clock-in time, schedule, and list upcoming alerts.

import SwiftUI

struct ContentView: View {
    @State private var clockIn = Date()
    
    // duration wheels (default 4 h 00 m)
    @State private var lunchHours   = 4
    @State private var lunchMinutes = 0
    
    @State private var showError = false
    @State private var errorMsg  = ""
    
    @ObservedObject private var notifier = NotificationManager.shared
    
    // convert the two wheels into seconds
    private var lunchOffset: TimeInterval {
        TimeInterval(lunchHours * 3600 + lunchMinutes * 60)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // CLOCK-IN (unchanged) ────────────────────────────────
                Section("Clock-in") {
                    DatePicker("Start time",
                               selection: $clockIn,
                               displayedComponents: [.hourAndMinute, .date])
                    .datePickerStyle(.compact)
                }
                
                // LUNCH STARTS IN (NEW WHEELS) ───────────────────────
                Section("Lunch starts in") {
                    HStack {
                        // hours: 0–4
                        Picker("Hours", selection: $lunchHours) {
                            ForEach(0...4, id:\.self) { Text("\($0) h") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        
                        // minutes: 0–59, but cap at 0-29 when hours == 4
                        Picker("Minutes", selection: $lunchMinutes) {
                            ForEach(0..<60, id:\.self) { m in
                                if !(lunchHours == 4 && m >= 30) {
                                    Text(String(format: "%02d m", m))
                                }
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .labelsHidden()
                }
                
                // SCHEDULE BUTTON & UPCOMING LIST (unchanged) ────────
                Section {
                    Button("Schedule / Update alerts") {
                        Task {
                            do {
                                try await notifier.scheduleAlerts(clockIn: clockIn,
                                                                  lunchStartOffset: lunchOffset)
                                HapticManager.shared.rumble()
                            } catch {
                                errorMsg  = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section("Upcoming alerts") {
                    if notifier.pending.isEmpty {
                        Text("No alerts scheduled")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(notifier.pending) { alert in
                            VStack(alignment: .leading) {
                                Text(alert.title)
                                Text(alert.fireDate, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workday Alerts")
            .alert("Invalid lunch time", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMsg) }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { Task { await notifier.refreshPending() } }
    }
}
