//
//  BrailleModeTogglePill.swift
//  Vibcom
//

import SwiftUI

struct BrailleModeTogglePill: View {
  @Binding var isOn: Bool
  var activeColor: Color = Color("MintGreen")
  private let labelWidth: CGFloat = 102
  private let horizontalInset: CGFloat = 10

  var body: some View {
    GeometryReader { geometry in
      let availableTrackWidth = max(
        140,
        geometry.size.width - labelWidth - (horizontalInset * 2) - 6
      )

      HStack(spacing: 6) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Braille Mode")
            .font(.footnote.weight(.semibold))
            .foregroundColor(.white.opacity(0.92))

          Text(isOn ? "Gesture input" : "Keyboard input")
            .font(.caption.weight(.medium))
            .foregroundColor(.white.opacity(0.60))
        }
        .frame(width: labelWidth, alignment: .leading)

        SwipeToggleControl(
          isOn: $isOn,
          activeColor: activeColor,
          width: availableTrackWidth,
          height: 34
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .padding(.leading, horizontalInset)
      .padding(.trailing, horizontalInset)
      .padding(.vertical, 10)
    }
    .frame(height: 54)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.09), Color.white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.16), lineWidth: 1)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(activeColor.opacity(0.12), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Braille Mode")
    .accessibilityValue(isOn ? "On" : "Off")
  }
}
