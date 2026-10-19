//
//  VibcomAccessibilityEngine.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/30/25.
//

import AVFoundation
import Foundation
import UIKit

final class VibcomAccessibilityEngine {

  static let shared = VibcomAccessibilityEngine()

  private let synthesizer = AVSpeechSynthesizer()

  var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate

  private init() {}

  func announceElement(
    label: String,
    hint: String? = nil,
    brailleEnabled: Bool
  ) {
    let phrase: String
    if let hint, !hint.isEmpty {
      phrase = "\(label). \(hint)"
    } else {
      phrase = label
    }

    if brailleEnabled {
      BraillePlaybackEngine.shared.readMessage(phrase, brailleEnabled: true)
    } else {
      speak(phrase)
    }
  }

  func confirmAction(
    label: String,
    brailleEnabled: Bool
  ) {
    let phrase = "\(label) selected."

    if brailleEnabled {
      BraillePlaybackEngine.shared.readMessage(phrase, brailleEnabled: true)
    } else {
      speak(phrase)
    }
  }

  private func speak(_ text: String) {
    guard !text.isEmpty else { return }
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = speechRate

    synthesizer.stopSpeaking(at: .immediate)
    synthesizer.speak(utterance)
  }
}
