import CoreHaptics
import UIKit

enum AppHapticEvent {
    case selection
    case action
    case confirmation
}

final class HapticsManager {
    static let shared = HapticsManager()

    private var splashEngine: CHHapticEngine?

    private init() {}

    func play(_ event: AppHapticEvent) {
        guard AppSettings.currentHapticsEnabled else { return }

        switch event {
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        case .action:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        case .confirmation:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }

    func playSplash() {
        guard AppSettings.currentHapticsEnabled,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let patternURL = Bundle.main.url(forResource: "splash_haptic", withExtension: "ahap") else {
            return
        }

        do {
            let engine = try CHHapticEngine()
            splashEngine = engine
            try engine.start()
            try engine.playPattern(from: patternURL)
        } catch {
            splashEngine = nil
        }
    }

    func stopSplash() {
        splashEngine?.stop()
        splashEngine = nil
    }
}
