//
//  SpeechManager.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/27/25.
//

import AVFoundation
import Foundation

final class SpeechManager {

  static let shared = SpeechManager()

  private let synthesizer = AVSpeechSynthesizer()

  private var wordsPerMinute: Int = 100 {
    didSet {
      wordsPerMinute = max(60, min(300, wordsPerMinute))
    }
  }

  private init() {
    prepareAudioSession()
  }

  func configure(wordsPerMinute: Int) {
    self.wordsPerMinute = wordsPerMinute
  }

  func speak(_ text: String, language: String = "en-US") {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    prepareAudioSession()

    if synthesizer.isSpeaking {
      synthesizer.stopSpeaking(at: .immediate)
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: language)

    let normalized = CGFloat(wordsPerMinute - 60) / CGFloat(300 - 60)
    let rate = Float(0.3 + (0.4 * normalized))
    utterance.rate = rate

    synthesizer.speak(utterance)
  }

  func stop() {
    synthesizer.stopSpeaking(at: .immediate)
  }

  private func prepareAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
      try session.setActive(true)
    } catch {
      print("Speech audio session error: \(error)")
    }
  }
}
