//
//  TwoFingerActivateCatcher.swift
//  Vibcom
//

import SwiftUI
import UIKit

struct TwoFingerActivateCatcher: UIViewRepresentable {
  let onActivate: () -> Void

  func makeUIView(context: Context) -> GestureInstallerView {
    let view = GestureInstallerView()
    view.coordinator = context.coordinator
    return view
  }

  func updateUIView(_ uiView: GestureInstallerView, context: Context) {
    context.coordinator.onActivate = onActivate
    uiView.coordinator = context.coordinator
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onActivate: onActivate)
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onActivate: () -> Void
    private weak var window: UIWindow?
    private var swipe: UISwipeGestureRecognizer?

    init(onActivate: @escaping () -> Void) {
      self.onActivate = onActivate
    }

    @objc func handleSwipe() {
      onActivate()
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

      let gesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
      gesture.numberOfTouchesRequired = 2
      gesture.direction = .left
      gesture.cancelsTouchesInView = false
      gesture.delegate = self
      window.addGestureRecognizer(gesture)

      self.window = window
      self.swipe = gesture
    }

    func detach() {
      if let swipe, let window {
        window.removeGestureRecognizer(swipe)
      }
      swipe = nil
      window = nil
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
