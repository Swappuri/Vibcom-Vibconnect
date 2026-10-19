//
//  DesignTokens.swift
//  Vibcom
//

import SwiftUI

enum VibcomSpace {
  static let xxs: CGFloat = 8
  static let xs: CGFloat = 12
  static let sm: CGFloat = 16
  static let md: CGFloat = 20
  static let lg: CGFloat = 24
  static let xl: CGFloat = 32
}

enum VibcomSize {
  static let minTap: CGFloat = 48
  static let primaryTap: CGFloat = 56
  static let rowHeight: CGFloat = 88
  static let cardHeight: CGFloat = 92
}

enum VibcomRadius {
  static let sm: CGFloat = 12
  static let md: CGFloat = 16
  static let lg: CGFloat = 24
}

enum VibcomStroke {
  static let normal: CGFloat = 1
  static let focus: CGFloat = 2
}

enum VibcomTypography {
  static let title = Font.system(size: 28, weight: .bold, design: .rounded)
  static let section = Font.system(size: 22, weight: .semibold, design: .rounded)
  static let body = Font.system(size: 17, weight: .regular, design: .rounded)
  static let action = Font.system(size: 17, weight: .semibold, design: .rounded)
  static let caption = Font.system(size: 15, weight: .medium, design: .rounded)
}

enum VibcomColor {
  static let background = Color.black
  static let surface = Color.white.opacity(0.06)
  static let surfaceElevated = Color.white.opacity(0.09)
  static let primaryAction = Color("MintGreen")
  static let destructive = Color.red
  static let textPrimary = Color.white
  static let textSecondary = Color.white.opacity(0.72)
  static let focusRing = Color("MintGreen")
}

extension View {
  func vibcomMinTapTarget(_ size: CGFloat = VibcomSize.minTap) -> some View {
    frame(minWidth: size, minHeight: size)
  }
}
