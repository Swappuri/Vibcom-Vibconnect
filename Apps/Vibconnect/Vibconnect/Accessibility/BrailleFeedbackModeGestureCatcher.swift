import SwiftUI
import UIKit

struct BrailleFeedbackModeGestureCatcher: UIViewRepresentable {
  let onCycle: () -> Void

  func makeUIView(context: Context) -> GestureInstallerView {
    let view = GestureInstallerView()
    view.coordinator = context.coordinator
    return view
  }

  func updateUIView(_ uiView: GestureInstallerView, context: Context) {
    context.coordinator.onCycle = onCycle
    uiView.coordinator = context.coordinator
  }

  func makeCoordinator() -> Coordinator { Coordinator(onCycle: onCycle) }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onCycle: () -> Void
    private weak var window: UIWindow?
    private var gesture: UITapGestureRecognizer?

    init(onCycle: @escaping () -> Void) { self.onCycle = onCycle }

    @objc func handleCycle() { onCycle() }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    func attach(to window: UIWindow?) {
      if self.window === window { return }
      detach()
      guard let window else { return }

      let g = UITapGestureRecognizer(target: self, action: #selector(handleCycle))
      g.numberOfTouchesRequired = 3
      g.numberOfTapsRequired = 1
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
