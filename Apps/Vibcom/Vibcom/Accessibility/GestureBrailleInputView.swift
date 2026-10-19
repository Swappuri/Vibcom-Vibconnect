//
//  GestureBrailleInputView.swift
//  Vibcom
//

import SwiftUI
import UIKit

struct GestureBrailleInputView: View {

  @EnvironmentObject private var appState: AppState

  @Binding var text: String
  let onSend: () -> Void
  var showComposePreview: Bool = true
  var usesNumericInput: Bool = false
  var contentHorizontalPadding: CGFloat = 16
  var padFillColor: Color = Color.white.opacity(0.03)
  var showsContainerBackground: Bool = true

  @State private var dots: [Bool] = []
  @State private var inputMode: InputMode = .braille

  private let maxDots = 6

  private enum InputMode {
    case braille
    case drawing
  }

  var body: some View {
    VStack(spacing: showComposePreview ? 12 : 0) {
      if showComposePreview {
        composePreview
      }
      if inputMode == .braille {
        gesturePad
      } else {
        handwritingPad
      }
    }
    .padding(.horizontal, contentHorizontalPadding)
    .padding(.top, 10)
    .padding(.bottom, 14)
    .background(
      Group {
        if showsContainerBackground {
          Color.black.ignoresSafeArea(edges: .bottom)
        } else {
          Color.clear
        }
      }
    )
    .accessibilityHidden(true)
    .onReceive(NotificationCenter.default.publisher(for: .didShakePhone)) { _ in
      deleteLastCharacter()
    }
  }

  private var composePreview: some View {
    Text(text.isEmpty ? "Message empty" : text)
      .font(.system(size: 20, weight: .semibold, design: .rounded))
      .foregroundColor(text.isEmpty ? .white.opacity(0.65) : .white)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white.opacity(0.04))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color("MintGreen").opacity(0.85), lineWidth: 1.6)
      )
  }

  private var gesturePad: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 22)
        .fill(padFillColor)
        .overlay(
          RoundedRectangle(cornerRadius: 22)
            .stroke(Color("MintGreen").opacity(0.70), lineWidth: 1.6)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 22)
            .stroke(
              Color("MintGreen").opacity(0.25),
              style: StrokeStyle(lineWidth: 1, dash: [8, 8])
            )
            .padding(10)
        )

      if dots.isEmpty {
        Image(systemName: "hand.draw")
          .font(.system(size: 40, weight: .regular))
          .foregroundColor(Color("MintGreen").opacity(0.30))
          .transition(.opacity)
      } else {
        BrailleCellInPad(dots: dots)
          .transition(.opacity)
      }
    }
    .frame(height: 250)
    .contentShape(Rectangle())
    .gesture(mainGesture)
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 0.7)
        .onEnded { _ in
          dots.removeAll()
          inputMode = .drawing
          HapticsManager.shared.play(.commitSuccess)
          BraillePlaybackEngine.shared.readMessage(
            "Drawing pad enabled. Draw a character.",
            brailleEnabled: appState.isBrailleModeActive
          )
        }
    )
    .animation(.snappy(duration: 0.18), value: dots.isEmpty)
  }

  private var handwritingPad: some View {
    HandwritingDrawingPad(
      text: $text,
      onSend: onSend,
      padFillColor: padFillColor,
      onExit: {
        inputMode = .braille
        HapticsManager.shared.play(.commitSuccess)
        BraillePlaybackEngine.shared.readMessage(
          "Braille gesture pad enabled.",
          brailleEnabled: appState.isBrailleModeActive
        )
      }
    )
  }

  private var mainGesture: some Gesture {
    let tapGesture = TapGesture(count: 2)
      .onEnded { sendMessage() }
      .exclusively(
        before:
          TapGesture(count: 1)
          .onEnded { insertSpace() }
      )

    return SimultaneousGesture(
      DragGesture(minimumDistance: 18)
        .onEnded { value in
          let dx = value.translation.width
          let dy = value.translation.height

          guard abs(dx) > abs(dy) else { return }

          if dx >= 28 {
            registerDot(true)
          } else if dx <= -28 {
            registerDot(false)
          }
        },
      tapGesture
    )
  }

  private func registerDot(_ raised: Bool) {
    guard dots.count < maxDots else { return }

    dots.append(raised)
    HapticsManager.shared.play(raised ? .dotOn : .dotOff)

    if dots.count == maxDots {
      commitCharacter()
    }
  }

  private func commitCharacter() {
    guard !dots.isEmpty else { return }

    if dots.count < maxDots {
      dots += Array(repeating: false, count: maxDots - dots.count)
    }

    if let char = BrailleTranslator.character(forDots: dots) {
      if usesNumericInput {
        if let digit = brailleCharToDigit(char) {
          text.append(digit)
          BraillePlaybackEngine.shared.readMessage(
            String(digit),
            brailleEnabled: appState.isBrailleModeActive
          )
        } else {
          HapticsManager.shared.play(.commitFailure)
        }
      } else {
        text.append(char)
        BraillePlaybackEngine.shared.readMessage(
          String(char),
          brailleEnabled: appState.isBrailleModeActive
        )
      }
    } else {
      HapticsManager.shared.play(.commitFailure)
    }

    dots.removeAll()
  }

  private func insertSpace() {
    if usesNumericInput == false {
      text.append(" ")
      HapticsManager.shared.play(.commitSuccess)
    }
    dots.removeAll()
  }

  private func deleteLastCharacter() {
    guard !text.isEmpty else { return }
    text.removeLast()
    HapticsManager.shared.play(.commitFailure)
    dots.removeAll()
  }

  private func sendMessage() {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    onSend()
    HapticsManager.shared.play(.commitSuccess)
    dots.removeAll()
  }

  private func brailleCharToDigit(_ char: Character) -> Character? {
    switch String(char).lowercased() {
    case "a": return "1"
    case "b": return "2"
    case "c": return "3"
    case "d": return "4"
    case "e": return "5"
    case "f": return "6"
    case "g": return "7"
    case "h": return "8"
    case "i": return "9"
    case "j": return "0"
    default: return nil
    }
  }
}

private struct HandwritingDrawingPad: View {
  @EnvironmentObject private var appState: AppState

  @Binding var text: String
  let onSend: () -> Void
  let padFillColor: Color
  let onExit: () -> Void

  @State private var strokes: [[CGPoint]] = []
  @State private var activeStroke: [CGPoint] = []
  @State private var recognitionTask: Task<Void, Never>?
  @State private var isRecognizing = false

  private let recognizer = HandwritingRecognitionEngine.shared

  var body: some View {
    GeometryReader { geo in
      ZStack {
        RoundedRectangle(cornerRadius: 22)
          .fill(padFillColor)
          .overlay(
            RoundedRectangle(cornerRadius: 22)
              .stroke(Color("MintGreen").opacity(0.70), lineWidth: 1.6)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 22)
              .stroke(
                Color("MintGreen").opacity(0.25),
                style: StrokeStyle(lineWidth: 1, dash: [8, 8])
              )
              .padding(10)
          )

        Path { path in
          for stroke in strokes where stroke.count > 1 {
            path.addLines(stroke)
          }
          if activeStroke.count > 1 {
            path.addLines(activeStroke)
          }
        }
        .stroke(
          Color("MintGreen"),
          style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
        )

        if strokes.isEmpty && activeStroke.isEmpty {
          Image(systemName: "pencil.and.scribble")
            .font(.system(size: 36, weight: .medium))
            .foregroundColor(Color("MintGreen").opacity(0.30))
        }
      }
      .contentShape(Rectangle())
      .gesture(drawingGesture(canvasSize: geo.size))
      .simultaneousGesture(tapActionsGesture)
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 0.7)
          .onEnded { _ in
            recognitionTask?.cancel()
            clearDrawing()
            onExit()
          }
      )
    }
    .frame(height: 250)
  }

  private func drawingGesture(canvasSize: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        if activeStroke.isEmpty {
          recognitionTask?.cancel()
        }
        activeStroke.append(value.location)
      }
      .onEnded { value in
        activeStroke.append(value.location)
        if activeStroke.count > 1 {
          strokes.append(activeStroke)
        }
        activeStroke.removeAll()
        scheduleRecognition(for: canvasSize)
      }
  }

  private var tapActionsGesture: some Gesture {
    TapGesture(count: 2)
      .onEnded { sendMessage() }
      .exclusively(
        before:
          TapGesture(count: 1)
          .onEnded { insertSpace() }
      )
  }

  private func insertSpace() {
    text.append(" ")
    HapticsManager.shared.play(.dotOn)
  }

  private func sendMessage() {
    guard !isRecognizing else { return }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onSend()
    HapticsManager.shared.play(.commitSuccess)
    clearDrawing()
  }

  private func clearDrawing() {
    strokes.removeAll()
    activeStroke.removeAll()
  }

  private func scheduleRecognition(for size: CGSize) {
    recognitionTask?.cancel()
    recognitionTask = Task {
      do {
        try await Task.sleep(nanoseconds: 1_050_000_000)
      } catch {
        return
      }
      if Task.isCancelled { return }
      await recognizeDrawing(in: size)
    }
  }

  @MainActor
  private func recognizeDrawing(in size: CGSize) async {
    guard !strokes.isEmpty else { return }
    isRecognizing = true

    do {
      let snapshot = strokes
      let recognized = try await recognizer.recognize(strokes: snapshot, canvasSize: size)

      guard recognized.isEmpty == false else {
        isRecognizing = false
        clearDrawing()
        HapticsManager.shared.play(.commitFailure)
        return
      }

      text.append(recognized)
      clearDrawing()
      isRecognizing = false
      HapticsManager.shared.play(.commitSuccess)
      BraillePlaybackEngine.shared.readMessage(
        recognized,
        brailleEnabled: appState.isBrailleModeActive
      )
    } catch {
      isRecognizing = false
      clearDrawing()
      HapticsManager.shared.play(.commitFailure)
    }
  }
}

private struct BrailleCellInPad: View {

  let dots: [Bool]

  private let dotSize: CGFloat = 34
  private let spacing: CGFloat = 28

  private func state(for index: Int) -> DotState {
    if index < dots.count {
      return dots[index] ? .raised : .flat
    }
    return .empty
  }

  var body: some View {
    let mint = Color("MintGreen")

    VStack(spacing: spacing) {
      HStack(spacing: spacing) {
        dotView(state: state(for: 0), mint: mint)
        dotView(state: state(for: 3), mint: mint)
      }
      HStack(spacing: spacing) {
        dotView(state: state(for: 1), mint: mint)
        dotView(state: state(for: 4), mint: mint)
      }
      HStack(spacing: spacing) {
        dotView(state: state(for: 2), mint: mint)
        dotView(state: state(for: 5), mint: mint)
      }
    }
  }

  private func dotView(state: DotState, mint: Color) -> some View {
    Circle()
      .fill(fillColor(for: state, mint: mint))
      .overlay(
        Circle()
          .stroke(strokeColor(for: state, mint: mint), lineWidth: 2)
      )
      .frame(width: dotSize, height: dotSize)
      .scaleEffect(state == .raised ? 1.08 : 1.0)
      .animation(.snappy(duration: 0.14), value: state)
  }

  private func fillColor(for state: DotState, mint: Color) -> Color {
    switch state {
    case .raised:
      return mint
    case .flat:
      return Color.black.opacity(0.0)
    case .empty:
      return Color.black.opacity(0.0)
    }
  }

  private func strokeColor(for state: DotState, mint: Color) -> Color {
    switch state {
    case .raised:
      return mint.opacity(0.95)
    case .flat:
      return mint.opacity(0.80)
    case .empty:
      return mint.opacity(0.28)
    }
  }

  private enum DotState {
    case empty
    case flat
    case raised
  }
}

extension UIWindow {
  open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
      NotificationCenter.default.post(name: .didShakePhone, object: nil)
    }
  }
}

extension Notification.Name {
  static let didShakePhone = Notification.Name("didShakePhone")
}
