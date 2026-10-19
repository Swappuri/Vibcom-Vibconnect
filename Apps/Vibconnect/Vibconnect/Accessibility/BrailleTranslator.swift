//
//  BrailleTranslator.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/26/25.
//

import Foundation

struct BrailleTranslator {
  private static let patternToCharacter: [String: Character] = [
    "100000": "a",
    "110000": "b",
    "100100": "c",
    "100110": "d",
    "100010": "e",
    "110100": "f",
    "110110": "g",
    "110010": "h",
    "010100": "i",
    "010110": "j",
    "101000": "k",
    "111000": "l",
    "101100": "m",
    "101110": "n",
    "101010": "o",
    "111100": "p",
    "111110": "q",
    "111010": "r",
    "011100": "s",
    "011110": "t",
    "101001": "u",
    "111001": "v",
    "010111": "w",
    "101101": "x",
    "101111": "y",
    "101011": "z",
    "000000": " ",
    "010011": ",",
    "010001": ";",
    "010010": ":",
    "010000": "'",
    "011000": "-",
    "011011": "!",
    "011010": "?",
    "011001": ".",
  ]

  static func character(forDots dots: [Bool]) -> Character? {
    guard dots.count == 6 else { return nil }
    let key = dots.map { $0 ? "1" : "0" }.joined()
    return patternToCharacter[key]
  }
}
