//
//  HapticManager.swift
//  TimedNotification
//
//  Created by Sibi on 5/12/25.
//

import CoreHaptics

final class HapticManager {
    static let shared = HapticManager()
    private var engine: CHHapticEngine?

    func rumble() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()

        // 0.5-s full-intensity rumble
        let ev = CHHapticEvent(eventType: .hapticContinuous,
                               parameters: [.init(parameterID: .hapticIntensity, value: 1)],
                               relativeTime: 0,
                               duration: 0.5)

        let pattern = try? CHHapticPattern(events: [ev], parameters: [])
        let player  = try? engine?.makePlayer(with: pattern!)
        try? player?.start(atTime: 0)
    }

    func stop() { engine?.stop(completionHandler: nil) }
}
