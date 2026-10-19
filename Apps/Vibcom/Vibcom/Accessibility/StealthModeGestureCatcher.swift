//
//  StealthModeGestureCatcher.swift
//  Vibcom
//

import SwiftUI
import UIKit

struct StealthModeGestureCatcher: UIViewRepresentable {
  let onToggle: () -> Void

  func makeUIView(context: Context) -> GestureInstallerView {
    let view = GestureInstallerView()
    view.coordinator = context.coordinator
    return view
  }

  func updateUIView(_ uiView: GestureInstallerView, context: Context) {
    context.coordinator.onToggle = onToggle
    uiView.coordinator = context.coordinator
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onToggle: onToggle)
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onToggle: () -> Void
    private weak var window: UIWindow?
    private var gesture: UITapGestureRecognizer?

    init(onToggle: @escaping () -> Void) {
      self.onToggle = onToggle
    }

    @objc func handleToggle() {
      onToggle()
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      true
    }

    func attach(to window: UIWindow?) {
      if self.window === window { return }
      detach()
      guard let window else { return }

      let gesture = UITapGestureRecognizer(target: self, action: #selector(handleToggle))
      gesture.numberOfTouchesRequired = 4
      gesture.numberOfTapsRequired = 2
      gesture.cancelsTouchesInView = false
      gesture.delaysTouchesBegan = false
      gesture.delaysTouchesEnded = false
      gesture.delegate = self
      window.addGestureRecognizer(gesture)

      self.window = window
      self.gesture = gesture
    }

    func detach() {
      if let gesture, let window {
        window.removeGestureRecognizer(gesture)
      }
      self.gesture = nil
      self.window = nil
    }
  }

  final class GestureInstallerView: UIView {
    weak var coordinator: Coordinator?

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
      super.init(coder: coder)
      isUserInteractionEnabled = false
      backgroundColor = .clear
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      coordinator?.attach(to: window)
    }

    deinit {
      coordinator?.detach()
    }
  }
}
