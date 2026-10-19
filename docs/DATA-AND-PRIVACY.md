# Data flows and privacy notes

This is a code-based inventory for development and review. It is not a user-facing privacy policy or a substitute for the app store privacy disclosures. Confirm every statement against the Firebase project, Firebase SDK behavior, and the release build before distribution.

## Data handled by the apps

- **Account and profile:** Vibcom uses Firebase phone authentication and stores account identifiers, phone numbers, display names, and presence data in Cloud Firestore.
- **Contacts:** Vibcom reads contact names and phone numbers after permission is granted and uses phone numbers in Firebase lookups to find existing users. Vibconnect reads contacts on-device to filter nearby results and may add an accepted person to the device address book.
- **Location:** Vibcom can write coordinates, a derived location cell, a timestamp, and a discoverability setting to Firestore for nearby discovery. Vibconnect reads the device location to find nearby profiles. Review the opt-in and deletion behavior before using the service with real users.
- **Messages:** Vibcom writes conversation participant identifiers, message text, usernames, and timestamps to Firestore.
- **Nearby exchange:** Vibconnect uses encrypted Multipeer Connectivity to exchange a user ID, phone number, and device name with a nearby peer.
- **Profile image:** Vibcom uses the system photo picker and stores the selected image in local SwiftData. The inspected source does not upload that image to Firebase.
- **Preferences:** Braille settings, skipped discovery results, and shared identity values are stored with UserDefaults, including app-group defaults shared by both apps.

## Before distribution

The app privacy manifests declare the app-level UserDefaults required reasons and source-visible data flows. Firebase SDKs have their own manifests. Recheck the generated app bundles and complete App Store privacy details against the release configuration; privacy disclosures depend on actual service settings and retention.

This repository does not include Firestore security rules or Firebase deployment files. Configure and review restrictive rules before connecting real users. In particular, protect profile and location records, contact matching queries, conversation membership, and message reads and writes. Define deletion and retention behavior for account, contact-matching, location, and message data.
