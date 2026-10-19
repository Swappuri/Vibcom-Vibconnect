//
//  AccessibilitySettings.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import Foundation
import SwiftData

@Model
final class AccessibilitySettings {

  @Attribute(.unique) var id: UUID

  var brailleModeEnabled: Bool
  var locationAccessEnabled: Bool
  var speechSpeedWPM: Double
  var vibrationFrequencyHz: Double
  var vibrationSpeedMultiplier: Double

  init(
    id: UUID = UUID(),
    brailleModeEnabled: Bool = true,
    locationAccessEnabled: Bool = false,
    speechSpeedWPM: Double = 100,
    vibrationFrequencyHz: Double = 150,
    vibrationSpeedMultiplier: Double = 1.0
  ) {
    self.id = id
    self.brailleModeEnabled = brailleModeEnabled
    self.locationAccessEnabled = locationAccessEnabled
    self.speechSpeedWPM = speechSpeedWPM

    self.vibrationFrequencyHz = vibrationFrequencyHz
    self.vibrationSpeedMultiplier = vibrationSpeedMultiplier
  }
}
