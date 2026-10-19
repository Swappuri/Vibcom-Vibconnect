import AVFoundation
import Darwin

final class VibcomToneEngine {
  static let shared = VibcomToneEngine()

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let format: AVAudioFormat
  private var isReady = false

  private init() {
    let sampleRate: Double = 44_100
    self.format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.35

    prepareAudioSession()
    startIfNeeded()
  }

  private func prepareAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      // Use playback so accessibility cues are still audible in silent mode.
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      print("Audio session error: \(error)")
    }
  }

  private func startIfNeeded() {
    guard !isReady else { return }
    do {
      try engine.start()
      isReady = true
    } catch {
      print("Audio engine start error: \(error)")
    }
  }

  func playStrongDot() { scheduleTone(frequency: 740, duration: 0.10, gain: 0.42, after: 0.01) }
  func playWeakDot() { scheduleTone(frequency: 420, duration: 0.10, gain: 0.10, after: 0.01) }
  func scheduleStrongDot(after delay: TimeInterval) {
    scheduleTone(frequency: 740, duration: 0.10, gain: 0.42, after: delay)
  }
  func scheduleWeakDot(after delay: TimeInterval) {
    scheduleTone(frequency: 420, duration: 0.10, gain: 0.10, after: delay)
  }
  func playCommitSuccess() {
    scheduleTone(frequency: 990, duration: 0.060, gain: 0.50, after: 0.01)
  }
  func playCommitFailure() {
    scheduleTone(frequency: 220, duration: 0.080, gain: 0.45, after: 0.01)
  }

  private func scheduleTone(
    frequency: Double, duration: Double, gain: Double, after delay: TimeInterval
  ) {
    startIfNeeded()

    let buffer = makeSineBuffer(frequency: frequency, duration: duration, gain: gain)
    let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: max(delay, 0.01))
    let startTime = AVAudioTime(hostTime: hostTime)
    player.scheduleBuffer(buffer, at: startTime, options: [], completionHandler: nil)

    if !player.isPlaying {
      player.play()
    }
  }

  func stopAll() {
    player.stop()
  }

  private func makeSineBuffer(frequency: Double, duration: Double, gain: Double) -> AVAudioPCMBuffer
  {
    let sampleRate = format.sampleRate
    let frameCount = AVAudioFrameCount(sampleRate * duration)

    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount

    let channel = buffer.floatChannelData![0]
    let twoPi = 2.0 * Double.pi
    var phase = 0.0
    let phaseIncrement = twoPi * frequency / sampleRate

    for i in 0..<Int(frameCount) {
      channel[i] = Float(sin(phase) * gain)
      phase += phaseIncrement
    }

    return buffer
  }
}
