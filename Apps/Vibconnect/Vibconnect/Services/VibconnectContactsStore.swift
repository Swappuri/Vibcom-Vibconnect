import Contacts
import Foundation

@MainActor
final class VibconnectContactsStore: NSObject, ObservableObject {
  @Published private(set) var saved: [NearbyPerson] = []

  private let defaultsKey = "vibconnect.saved.people"
  private let store = CNContactStore()
  private var observer: NSObjectProtocol?

  override init() {
    super.init()
    guard
      let data = UserDefaults.standard.data(forKey: defaultsKey),
      let decoded = try? JSONDecoder().decode([NearbyPerson].self, from: data)
    else {
      installObserver()
      Task { await refreshFromDeviceContacts() }
      return
    }
    saved = decoded
    installObserver()
    Task { await refreshFromDeviceContacts() }
  }

  func add(_ person: NearbyPerson) {
    if !saved.contains(where: { $0.phoneE164 == person.phoneE164 }) {
      saved.insert(person, at: 0)
      persistSaved()
    }
    Task {
      await addToDeviceContactsIfPossible(person)
      await refreshFromDeviceContacts()
    }
  }

  func refreshFromDeviceContacts() async {
    let status = CNContactStore.authorizationStatus(for: .contacts)

    if status == .notDetermined {
      _ = try? await store.requestAccess(for: .contacts)
    }

    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return }

    let deviceNumbers = await fetchDeviceContactPhoneSet()
    let filtered = saved.filter { person in
      deviceNumbers.contains(Self.normalizedUSNumber(person.phoneE164))
    }

    if filtered != saved {
      saved = filtered
      persistSaved()
    }
  }

  private func addToDeviceContactsIfPossible(_ person: NearbyPerson) async {
    if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
      _ = try? await store.requestAccess(for: .contacts)
    }
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return }
    guard await contactExists(with: person.phoneE164, in: store) == false else { return }

    let contact = CNMutableContact()
    // Keep the number as the visible contact name so users can distinguish entries.
    contact.givenName = person.phoneNumber
    contact.familyName = ""
    contact.phoneNumbers = [
      CNLabeledValue(
        label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: person.phoneNumber))
    ]

    let save = CNSaveRequest()
    save.add(contact, toContainerWithIdentifier: nil)
    try? store.execute(save)
  }

  private func fetchDeviceContactPhoneSet() async -> Set<String> {
    let keys: [CNKeyDescriptor] = [CNContactPhoneNumbersKey as CNKeyDescriptor]
    let request = CNContactFetchRequest(keysToFetch: keys)
    var phoneSet: Set<String> = []

    try? store.enumerateContacts(with: request) { contact, _ in
      for value in contact.phoneNumbers {
        phoneSet.insert(Self.normalizedUSNumber(value.value.stringValue))
      }
    }

    return phoneSet
  }

  private func installObserver() {
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: .CNContactStoreDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        await self.refreshFromDeviceContacts()
      }
    }
  }

  private func persistSaved() {
    if let encoded = try? JSONEncoder().encode(saved) {
      UserDefaults.standard.set(encoded, forKey: defaultsKey)
    }
  }

  private func contactExists(with phoneE164: String, in store: CNContactStore) async -> Bool {
    let normalizedTarget = Self.normalizedUSNumber(phoneE164)
    let keys: [CNKeyDescriptor] = [CNContactPhoneNumbersKey as CNKeyDescriptor]
    let request = CNContactFetchRequest(keysToFetch: keys)
    var found = false

    try? store.enumerateContacts(with: request) { contact, stop in
      if found {
        stop.pointee = true
        return
      }
      for value in contact.phoneNumbers {
        let existing = Self.normalizedUSNumber(value.value.stringValue)
        if existing == normalizedTarget {
          found = true
          stop.pointee = true
          return
        }
      }
    }
    return found
  }

  private static func normalizedUSNumber(_ raw: String) -> String {
    let digits = raw.filter(\.isNumber)
    if digits.count == 11, digits.first == "1" {
      return "+" + digits
    }
    if digits.count == 10 {
      return "+1" + digits
    }
    return "+" + digits
  }
}
