import AVFoundation
import Foundation

final class SpeechManager {
  static let shared = SpeechManager()

  private let synthesizer = AVSpeechSynthesizer()
  private var wordsPerMinute: Int = 100 {
    didSet { wordsPerMinute = max(60, min(300, wordsPerMinute)) }
  }

  private init() {}

  func configure(wordsPerMinute: Int) {
    self.wordsPerMinute = wordsPerMinute
  }

  func speak(_ text: String, language: String = "en-US") {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    if synthesizer.isSpeaking {
      synthesizer.stopSpeaking(at: .immediate)
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: language)
    let normalized = CGFloat(wordsPerMinute - 60) / CGFloat(300 - 60)
    utterance.rate = Float(0.3 + (0.4 * normalized))
    synthesizer.speak(utterance)
  }

  func stop() {
    synthesizer.stopSpeaking(at: .immediate)
  }
}
