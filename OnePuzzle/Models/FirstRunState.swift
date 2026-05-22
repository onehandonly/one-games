import Foundation
import Observation

@Observable
final class FirstRunState {
    var hasSeenWelcome: Bool {
        didSet { defaults.set(hasSeenWelcome, forKey: FirstRunDefaults.hasSeenWelcome) }
    }
    var hasSeenHowItWorks: Bool {
        didSet { defaults.set(hasSeenHowItWorks, forKey: FirstRunDefaults.hasSeenHowItWorks) }
    }
    var hasShownFirstCellHint: Bool {
        didSet { defaults.set(hasShownFirstCellHint, forKey: FirstRunDefaults.hasShownFirstCellHint) }
    }
    var hasShownNumberPadHint: Bool {
        didSet { defaults.set(hasShownNumberPadHint, forKey: FirstRunDefaults.hasShownNumberPadHint) }
    }
    var notifPrePromptDeclinedAt: Date? {
        didSet {
            if let date = notifPrePromptDeclinedAt {
                defaults.set(date, forKey: FirstRunDefaults.notifPrePromptDeclinedAt)
            } else {
                defaults.removeObject(forKey: FirstRunDefaults.notifPrePromptDeclinedAt)
            }
        }
    }
    var notifOSDenied: Bool {
        didSet { defaults.set(notifOSDenied, forKey: FirstRunDefaults.notifOSDenied) }
    }
    var hasShownNotificationPrePrompt: Bool {
        didSet { defaults.set(hasShownNotificationPrePrompt, forKey: FirstRunDefaults.hasShownNotificationPrePrompt) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasSeenWelcome = defaults.bool(forKey: FirstRunDefaults.hasSeenWelcome)
        self.hasSeenHowItWorks = defaults.bool(forKey: FirstRunDefaults.hasSeenHowItWorks)
        self.hasShownFirstCellHint = defaults.bool(forKey: FirstRunDefaults.hasShownFirstCellHint)
        self.hasShownNumberPadHint = defaults.bool(forKey: FirstRunDefaults.hasShownNumberPadHint)
        self.notifPrePromptDeclinedAt = defaults.object(forKey: FirstRunDefaults.notifPrePromptDeclinedAt) as? Date
        self.notifOSDenied = defaults.bool(forKey: FirstRunDefaults.notifOSDenied)
        self.hasShownNotificationPrePrompt = defaults.bool(forKey: FirstRunDefaults.hasShownNotificationPrePrompt)
    }

    var isFreshInstall: Bool {
        !hasSeenWelcome && !hasSeenHowItWorks
    }

    var isNotificationPrePromptInCooldown: Bool {
        guard let declined = notifPrePromptDeclinedAt else { return false }
        return declined > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    }

    var canShowNotificationPrePrompt: Bool {
        guard !hasShownNotificationPrePrompt else { return false }
        guard !notifOSDenied else { return false }
        guard !isNotificationPrePromptInCooldown else { return false }
        return true
    }
}

enum FirstRunDefaults {
    static let hasSeenWelcome                 = "onepuzzle.hasSeenWelcome"
    static let hasSeenHowItWorks              = "onepuzzle.hasSeenHowItWorks"
    static let hasShownFirstCellHint          = "onepuzzle.hasShownFirstCellHint"
    static let hasShownNumberPadHint          = "onepuzzle.hasShownNumberPadHint"
    static let notifPrePromptDeclinedAt       = "onepuzzle.notifPrePromptDeclinedAt"
    static let notifOSDenied                  = "onepuzzle.notifOSDenied"
    static let hasShownNotificationPrePrompt  = "onepuzzle.hasShownNotificationPrePrompt"
}
