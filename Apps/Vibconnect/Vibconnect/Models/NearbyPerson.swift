import Foundation

struct NearbyPerson: Identifiable, Equatable, Hashable, Codable {
  let id: String
  let phoneE164: String
  let latitude: Double?
  let longitude: Double?
  let distanceMeters: Double?

  var phoneNumber: String {
    PhoneDisplayFormatter.usPretty(phoneE164: phoneE164)
  }
}

enum NearbyDecision {
  case accepted
  case passed
}

enum PhoneDisplayFormatter {
  static func usPretty(phoneE164: String) -> String {
    let digits = phoneE164.filter(\.isNumber)
    let tenDigits: String
    if digits.count == 11, digits.first == "1" {
      tenDigits = String(digits.dropFirst())
    } else {
      tenDigits = String(digits.prefix(10))
    }

    guard tenDigits.count == 10 else { return phoneE164 }
    let area = tenDigits.prefix(3)
    let prefix = tenDigits.dropFirst(3).prefix(3)
    let line = tenDigits.dropFirst(6)
    return "+1 (\(area)) \(prefix)-\(line)"
  }
}
