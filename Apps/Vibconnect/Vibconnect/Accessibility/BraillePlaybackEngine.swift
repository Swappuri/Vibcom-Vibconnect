//
//  BraillePlaybackEngine.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/30/25.
//

import AVFoundation
import Foundation
import UIKit

final class BraillePlaybackEngine {

  static let shared = BraillePlaybackEngine()
  private let synthesizer = AVSpeechSynthesizer()
  private var scheduledHapticWork: [DispatchWorkItem] = []
  private var lastRequestedText: String?
  private var lastBrailleEnabled = false

  var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
  var vibrationSpeedMultiplier: Double = 1.0
  var feedbackMode: BrailleFeedbackMode {
    get { BrailleFeedbackPreferences.mode }
    set { BrailleFeedbackPreferences.mode = newValue }
  }

  private init() {
    prepareAudioSession()
  }

  func readMessage(_ text: String, brailleEnabled: Bool) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    lastRequestedText = trimmed
    lastBrailleEnabled = brailleEnabled
    cancelPendingBrailleFeedback()
    synthesizer.stopSpeaking(at: .immediate)

    guard brailleEnabled else { return }

    switch feedbackMode {
    case .both:
      speak(trimmed)
      playTonesForText(trimmed)
    case .speechOnly:
      speak(trimmed)
    case .tonesOnly:
      playTonesForText(trimmed)
    }
  }

  private func speak(_ text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = speechRate
    synthesizer.speak(utterance)
  }

  private func playTonesForText(_ text: String) {
    let chars = Array(text.lowercased().prefix(24))
    var slotIndex = 0

    let baseSlotInterval: TimeInterval = 0.22
    let baseCharacterGapSlots = 1
    let baseWordGapSlots = 3

    let speed = max(vibrationSpeedMultiplier, 0.1)
    let slotInterval = baseSlotInterval / speed

    for ch in chars {
      if ch == " " {
        slotIndex += baseWordGapSlots
        continue
      }

      guard let dots = Self.dots(for: ch) else {
        slotIndex += 6 + baseCharacterGapSlots
        continue
      }

      for dotIndex in 1...6 {
        let isStrong = dots.contains(dotIndex)
        let delay = TimeInterval(slotIndex) * slotInterval + 0.03

        if isStrong {
          let work = DispatchWorkItem {
            HapticsManager.shared.play(.dotOn)
          }
          scheduledHapticWork.append(work)
          DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
          VibcomToneEngine.shared.scheduleStrongDot(after: delay)
        } else {
          VibcomToneEngine.shared.scheduleWeakDot(after: delay)
        }
        slotIndex += 1
      }

      slotIndex += baseCharacterGapSlots
    }
  }

  private func cancelPendingBrailleFeedback() {
    for workItem in scheduledHapticWork {
      workItem.cancel()
    }
    scheduledHapticWork.removeAll(keepingCapacity: true)
    VibcomToneEngine.shared.stopAll()
  }

  func stopAllOutput() {
    cancelPendingBrailleFeedback()
    synthesizer.stopSpeaking(at: .immediate)
  }

  func cycleFeedbackMode() {
    let nextMode = feedbackMode.next()
    feedbackMode = nextMode
    stopAllOutput()

    guard lastBrailleEnabled, let lastRequestedText else { return }
    readMessage(lastRequestedText, brailleEnabled: true)
  }

  // MARK: - Beeps

  private func prepareAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      // Keep spoken/braille audio cues audible even if device is in silent mode.
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      print("Audio session error: \(error)")
    }
  }

  // MARK: - Braille Map

  private static func dots(for char: Character) -> [Int]? {
    switch char {
    case "1": return [1]  // number sign + a
    case "2": return [1, 2]  // number sign + b
    case "3": return [1, 4]  // number sign + c
    case "4": return [1, 4, 5]  // number sign + d
    case "5": return [1, 5]  // number sign + e
    case "6": return [1, 2, 4]  // number sign + f
    case "7": return [1, 2, 4, 5]  // number sign + g
    case "8": return [1, 2, 5]  // number sign + h
    case "9": return [2, 4]  // number sign + i
    case "0": return [2, 4, 5]  // number sign + j
    case "a": return [1]
    case "b": return [1, 2]
    case "c": return [1, 4]
    case "d": return [1, 4, 5]
    case "e": return [1, 5]
    case "f": return [1, 2, 4]
    case "g": return [1, 2, 4, 5]
    case "h": return [1, 2, 5]
    case "i": return [2, 4]
    case "j": return [2, 4, 5]
    case "k": return [1, 3]
    case "l": return [1, 2, 3]
    case "m": return [1, 3, 4]
    case "n": return [1, 3, 4, 5]
    case "o": return [1, 3, 5]
    case "p": return [1, 2, 3, 4]
    case "q": return [1, 2, 3, 4, 5]
    case "r": return [1, 2, 3, 5]
    case "s": return [2, 3, 4]
    case "t": return [2, 3, 4, 5]
    case "u": return [1, 3, 6]
    case "v": return [1, 2, 3, 6]
    case "w": return [2, 4, 5, 6]
    case "x": return [1, 3, 4, 6]
    case "y": return [1, 3, 4, 5, 6]
    case "z": return [1, 3, 5, 6]
    default:
      return nil
    }
  }
}
