# Firebase setup

1. Create or select a Firebase project and register separate iOS apps for Vibcom and Vibconnect.
2. Set unique bundle identifiers in each Xcode project. Use those exact identifiers when registering the Firebase apps.
3. Download each app-specific `GoogleService-Info.plist` and place it in the matching synchronized app source folder: `Apps/Vibcom/Vibcom/` or `Apps/Vibconnect/Vibconnect/`. The plist is ignored by Git.
4. In Vibcom's `Info.plist`, replace the Firebase URL scheme with the `REVERSED_CLIENT_ID` from the Vibcom Firebase configuration.
5. Enable the Firebase Authentication providers used by the app and Cloud Firestore. Review the Firestore fields and queries in `FirebaseUserStore.swift`, `FirestoreChatStore.swift`, and Vibconnect's discovery service.
6. Create and test Firestore security rules and any required indexes in your Firebase project. No production rules are included in this repository.
7. Register the App Group in the Apple Developer account and enable it for both apps. Keep the identifier consistent in both `.entitlements` files and both `SharedIdentityStore.swift` files.
8. Select your development team and confirm that the App Group entitlement is available to that team before installing on a device.

Firebase client configuration identifies a Firebase project; it is not a substitute for Authentication or Firestore security rules. Never commit service-account credentials, private keys, provisioning profiles, or production data.
