import Foundation

enum BrailleFeedbackMode: String, CaseIterable {
  case both
  case speechOnly
  case tonesOnly

  var displayName: String {
    switch self {
    case .both:
      return "Speech and Tones"
    case .speechOnly:
      return "Speech Only"
    case .tonesOnly:
      return "Tones Only"
    }
  }

  func next() -> BrailleFeedbackMode {
    switch self {
    case .speechOnly: return .tonesOnly
    case .tonesOnly: return .both
    case .both: return .speechOnly
    }
  }
}

enum BrailleFeedbackPreferences {
  private static let appGroupIdentifier = SharedIdentityStore.appGroupIdentifier
  private static let modeKey = "brailleFeedback.mode"

  private static var defaults: UserDefaults {
    UserDefaults(suiteName: appGroupIdentifier) ?? .standard
  }

  static var mode: BrailleFeedbackMode {
    get {
      guard
        let rawValue = defaults.string(forKey: modeKey),
        let mode = BrailleFeedbackMode(rawValue: rawValue)
      else {
        return .speechOnly
      }
      return mode
    }
    set {
      defaults.set(newValue.rawValue, forKey: modeKey)
    }
  }
}
