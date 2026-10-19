//
//  EditProfileView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/28/25.
//

import SwiftData
import SwiftUI

struct EditProfileView: View {

  @Environment(\.modelContext) private var modelContext

  @Bindable var user: VibcomUser

  @State private var email: String = ""
  @State private var username: String = ""
  @State private var displayName: String = ""
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  @State private var successMessage: String?

  var body: some View {
    Form {
      Section("Profile Info") {
        TextField("Display Name", text: $displayName)
          .textContentType(.name)

        TextField("Username", text: $username)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        TextField("Email", text: $email)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      }

      if let errorMessage {
        Section {
          Text(errorMessage)
            .foregroundStyle(.red)
            .font(.footnote)
        }
      }

      if let successMessage {
        Section {
          Text(successMessage)
            .foregroundStyle(.green)
            .font(.footnote)
        }
      }

      Section {
        Button {
          saveChanges()
        } label: {
          if isSaving {
            ProgressView()
          } else {
            Text("Save Changes")
              .font(.headline)
          }
        }
        .disabled(!isInputValid || isSaving)
      }
    }
    .navigationTitle("Edit Profile")
    .onAppear {
      email = user.email
      username = user.username
      displayName = user.displayName
    }
  }

  private var isInputValid: Bool {
    !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func saveChanges() {
    errorMessage = nil
    successMessage = nil

    let trimmedEmail =
      email
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let trimmedUsername =
      username
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedDisplayName =
      displayName
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard isInputValid else {
      errorMessage = "All fields are required."
      return
    }

    let currentUserID = user.id

    isSaving = true

    Task { @MainActor in
      defer { isSaving = false }

      do {
        var emailDescriptor = FetchDescriptor<VibcomUser>(
          predicate: #Predicate { u in
            u.email == trimmedEmail && u.id != currentUserID
          }
        )
        emailDescriptor.fetchLimit = 1
        let emailMatches = try modelContext.fetch(emailDescriptor)

        if !emailMatches.isEmpty {
          errorMessage = "That email is already associated with another account."
          return
        }

        var usernameDescriptor = FetchDescriptor<VibcomUser>(
          predicate: #Predicate { u in
            u.username == trimmedUsername && u.id != currentUserID
          }
        )
        usernameDescriptor.fetchLimit = 1
        let usernameMatches = try modelContext.fetch(usernameDescriptor)

        if !usernameMatches.isEmpty {
          errorMessage = "That username is already taken."
          return
        }

        user.email = trimmedEmail
        user.username = trimmedUsername
        user.displayName = trimmedDisplayName

        try modelContext.save()
        successMessage = "Profile updated successfully."

      } catch {
        errorMessage = "Unable to save changes right now. Please try again."
        print("EditProfileView save error: \(error)")
      }
    }
  }
}
