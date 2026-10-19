//
//  AuthComponents.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/28/25.
//

import SwiftUI

struct AuthTextField: View {
  let iconName: String
  let placeholder: String
  @Binding var text: String
  var keyboardType: UIKeyboardType = .default
  let mintGreen: Color

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: iconName)
        .foregroundColor(mintGreen)
        .frame(width: 22, alignment: .center)

      ZStack(alignment: .leading) {
        if text.isEmpty {
          Text(placeholder)
            .foregroundColor(.white.opacity(0.6))
        }
        TextField("", text: $text)
          .keyboardType(keyboardType)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .foregroundColor(.white)
      }
    }
    .font(VibcomTypography.body)
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 18)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(Color.white.opacity(0.16), lineWidth: 1)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(mintGreen.opacity(0.16), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
  }
}

struct AuthPasswordField: View {
  let iconName: String
  let placeholder: String
  @Binding var text: String
  @Binding var isVisible: Bool
  let mintGreen: Color

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: iconName)
        .foregroundColor(mintGreen)
        .frame(width: 22, alignment: .center)

      ZStack(alignment: .leading) {
        if text.isEmpty {
          Text(placeholder)
            .foregroundColor(.white.opacity(0.6))
        }
        Group {
          if isVisible {
            TextField("", text: $text)
          } else {
            SecureField("", text: $text)
          }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .foregroundColor(.white)
      }

      Spacer()

      Button {
        isVisible.toggle()
      } label: {
        Image(systemName: isVisible ? "eye.slash" : "eye")
          .foregroundColor(mintGreen)
      }
    }
    .font(VibcomTypography.body)
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 18)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(Color.white.opacity(0.16), lineWidth: 1)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(mintGreen.opacity(0.16), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
  }
}
