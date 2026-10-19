import Foundation

struct SharedIdentityStore {
  static let appGroupIdentifier = "group.com.example.www.vibcom.shared"

  private static let uidKey = "sharedIdentity.uid"
  private static let phoneE164Key = "sharedIdentity.phoneE164"

  private static var defaults: UserDefaults {
    UserDefaults(suiteName: appGroupIdentifier) ?? .standard
  }

  static var currentUID: String? {
    defaults.string(forKey: uidKey)
  }

  static var currentPhoneE164: String? {
    defaults.string(forKey: phoneE164Key)
  }

  static func save(uid: String, phoneE164: String) {
    defaults.set(uid, forKey: uidKey)
    defaults.set(phoneE164, forKey: phoneE164Key)
  }

  static func clear() {
    defaults.removeObject(forKey: uidKey)
    defaults.removeObject(forKey: phoneE164Key)
  }
}
