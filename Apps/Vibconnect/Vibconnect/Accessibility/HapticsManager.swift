import Foundation
import UIKit

final class HapticsManager {
  static let shared = HapticsManager()

  private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
  private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
  private let notificationGenerator = UINotificationFeedbackGenerator()
  private var intensity: CGFloat = 0.7

  private init() {
    lightImpactGenerator.prepare()
    mediumImpactGenerator.prepare()
    notificationGenerator.prepare()
  }

  enum FeedbackType {
    case dotOn
    case dotOff
    case commitSuccess
    case commitFailure
  }

  func configure(intensityHz: Int) {
    let clampedHz = max(50, min(300, intensityHz))
    let normalized = (CGFloat(clampedHz) - 50.0) / (300.0 - 50.0)
    self.intensity = max(0.2, min(1.0, normalized))
  }

  func play(_ type: FeedbackType) {
    switch type {
    case .dotOn:
      lightImpactGenerator.impactOccurred(intensity: intensity)
    case .dotOff:
      lightImpactGenerator.impactOccurred(intensity: max(0.2, intensity * 0.6))
    case .commitSuccess:
      mediumImpactGenerator.impactOccurred(intensity: intensity)
    case .commitFailure:
      notificationGenerator.notificationOccurred(.error)
    }
  }
}
