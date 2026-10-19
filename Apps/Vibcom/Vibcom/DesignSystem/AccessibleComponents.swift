//
//  AccessibleComponents.swift
//  Vibcom
//

import SwiftUI

struct AccessibleModeBanner: View {
  let title: String
  let value: String
  let hint: String
  let onActivate: () -> Void

  var body: some View {
    Button(action: onActivate) {
      HStack(spacing: VibcomSpace.xs) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(VibcomTypography.caption.weight(.semibold))
            .foregroundColor(VibcomColor.textPrimary)

          Text(value)
            .font(VibcomTypography.caption)
            .foregroundColor(VibcomColor.textSecondary)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(VibcomColor.primaryAction)
      }
      .padding(.horizontal, VibcomSpace.xs)
      .padding(.vertical, VibcomSpace.xs)
      .background(VibcomColor.surface)
      .overlay(
        RoundedRectangle(cornerRadius: VibcomRadius.md)
          .stroke(VibcomColor.focusRing.opacity(0.2), lineWidth: VibcomStroke.normal)
      )
      .clipShape(RoundedRectangle(cornerRadius: VibcomRadius.md))
    }
    .buttonStyle(.plain)
    .vibcomMinTapTarget()
    .accessibilityLabel(title)
    .accessibilityValue(value)
    .accessibilityHint(hint)
  }
}

struct AccessiblePrimaryButton: View {
  let title: String
  let hint: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(VibcomTypography.action)
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .frame(height: VibcomSize.primaryTap)
        .background(VibcomColor.primaryAction)
        .clipShape(RoundedRectangle(cornerRadius: VibcomRadius.md))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityHint(hint)
  }
}
