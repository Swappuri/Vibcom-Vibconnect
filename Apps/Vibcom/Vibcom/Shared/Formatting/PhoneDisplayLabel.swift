//
//  PhoneDisplayLabel.swift
//  Vibcom
//

import Foundation

enum PhoneDisplayLabel {
  static func formattedIfPhone(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return value }

    let digits = trimmed.filter(\.isNumber)
    let tenDigits: String

    if digits.count == 10 {
      tenDigits = digits
    } else if digits.count == 11, digits.first == "1" {
      tenDigits = String(digits.dropFirst())
    } else {
      return trimmed
    }

    let area = tenDigits.prefix(3)
    let exchange = tenDigits.dropFirst(3).prefix(3)
    let line = tenDigits.dropFirst(6)
    return "(\(area)) \(exchange) \(line)"
  }

  static func resolvedName(displayName: String, username: String) -> String {
    let trimmedDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedDisplay.isEmpty == false && trimmedDisplay != "Vibcom User" {
      return formattedIfPhone(trimmedDisplay)
    }
    return formattedIfPhone(username)
  }
}
