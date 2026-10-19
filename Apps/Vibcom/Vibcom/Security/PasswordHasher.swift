//
//  PasswordHasher.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import CryptoKit
import Foundation

struct PasswordHasher {

  static func hash(_ password: String) -> String {
    let data = Data(password.utf8)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
