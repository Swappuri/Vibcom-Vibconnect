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

  func makeCoordinator() -> Coordinator { Coordinator(onToggle: onToggle) }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onToggle: () -> Void
    private weak var window: UIWindow?
    private var gesture: UITapGestureRecognizer?

    init(onToggle: @escaping () -> Void) { self.onToggle = onToggle }
    @objc func handleToggle() { onToggle() }
    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    func attach(to window: UIWindow?) {
      if self.window === window { return }
      detach()
      guard let window else { return }
      let g = UITapGestureRecognizer(target: self, action: #selector(handleToggle))
      g.numberOfTouchesRequired = 4
      g.numberOfTapsRequired = 2
      g.cancelsTouchesInView = false
      g.delegate = self
      window.addGestureRecognizer(g)
      self.window = window
      self.gesture = g
    }

    func detach() {
      if let gesture, let window { window.removeGestureRecognizer(gesture) }
      gesture = nil
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

    deinit { coordinator?.detach() }
  }
}

struct TwoFingerOpenSavedCatcher: UIViewRepresentable {
  let onOpen: () -> Void

  func makeUIView(context: Context) -> GestureInstallerView {
    let view = GestureInstallerView()
    view.coordinator = context.coordinator
    return view
  }

  func updateUIView(_ uiView: GestureInstallerView, context: Context) {
    context.coordinator.onOpen = onOpen
    uiView.coordinator = context.coordinator
  }

  func makeCoordinator() -> Coordinator { Coordinator(onOpen: onOpen) }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onOpen: () -> Void
    private weak var window: UIWindow?
    private var gesture: UISwipeGestureRecognizer?

    init(onOpen: @escaping () -> Void) { self.onOpen = onOpen }
    @objc func handleOpen() { onOpen() }
    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    func attach(to window: UIWindow?) {
      if self.window === window { return }
      detach()
      guard let window else { return }
      let g = UISwipeGestureRecognizer(target: self, action: #selector(handleOpen))
      g.numberOfTouchesRequired = 2
      g.direction = .up
      g.cancelsTouchesInView = false
      g.delegate = self
      window.addGestureRecognizer(g)
      self.window = window
      self.gesture = g
    }

    func detach() {
      if let gesture, let window { window.removeGestureRecognizer(gesture) }
      gesture = nil
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

    deinit { coordinator?.detach() }
  }
}

struct TwoFingerOpenNearbyExchangeCatcher: UIViewRepresentable {
  let onOpen: () -> Void

  func makeUIView(context: Context) -> GestureInstallerView {
    let view = GestureInstallerView()
    view.coordinator = context.coordinator
    return view
  }

  func updateUIView(_ uiView: GestureInstallerView, context: Context) {
    context.coordinator.onOpen = onOpen
    uiView.coordinator = context.coordinator
  }

  func makeCoordinator() -> Coordinator { Coordinator(onOpen: onOpen) }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onOpen: () -> Void
    private weak var window: UIWindow?
    private var gesture: UISwipeGestureRecognizer?

    init(onOpen: @escaping () -> Void) { self.onOpen = onOpen }
    @objc func handleOpen() { onOpen() }
    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    func attach(to window: UIWindow?) {
      if self.window === window { return }
      detach()
      guard let window else { return }
      let g = UISwipeGestureRecognizer(target: self, action: #selector(handleOpen))
      g.numberOfTouchesRequired = 2
      g.direction = .down
      g.cancelsTouchesInView = false
      g.delegate = self
      window.addGestureRecognizer(g)
      self.window = window
      self.gesture = g
    }

    func detach() {
      if let gesture, let window { window.removeGestureRecognizer(gesture) }
      gesture = nil
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

    deinit { coordinator?.detach() }
  }
}
