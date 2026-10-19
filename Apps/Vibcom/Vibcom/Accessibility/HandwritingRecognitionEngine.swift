//
//  HandwritingRecognitionEngine.swift
//  Vibcom
//

import CoreGraphics
import CoreImage
import Foundation
import UIKit
import Vision

enum HandwritingRecognitionError: Error {
  case unsupported
  case noResult
}

final class HandwritingRecognitionEngine {
  static let shared = HandwritingRecognitionEngine()

  private init() {}

  func recognize(strokes: [[CGPoint]], canvasSize: CGSize) async throws -> String {
    guard strokes.isEmpty == false else {
      throw HandwritingRecognitionError.noResult
    }

    if let visionResult = try await recognizeWithVision(strokes: strokes, canvasSize: canvasSize),
      visionResult.isEmpty == false
    {
      return visionResult
    }

    if let templateResult = recognizeWithTemplateMatching(strokes: strokes, canvasSize: canvasSize),
      templateResult.isEmpty == false
    {
      return templateResult
    }

    throw HandwritingRecognitionError.noResult
  }
}

extension HandwritingRecognitionEngine {
  private static let templateCharacters: [Character] = Array(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
  private static let templateFonts: [UIFont] = [
    .systemFont(ofSize: 74, weight: .regular),
    .systemFont(ofSize: 74, weight: .medium),
    .italicSystemFont(ofSize: 74),
    .monospacedSystemFont(ofSize: 74, weight: .regular),
  ]
  private static let bitmapSize = 40
  private static let inkThreshold: UInt8 = 175

  fileprivate func recognizeWithTemplateMatching(strokes: [[CGPoint]], canvasSize: CGSize)
    -> String?
  {
    let drawing = drawingImage(from: strokes, canvasSize: canvasSize)
    guard let drawingVector = imageToBinaryVector(drawing) else { return nil }

    var ranked: [(char: Character, score: Double)] = []
    ranked.reserveCapacity(Self.templateCharacters.count * Self.templateFonts.count)

    for candidate in Self.templateCharacters {
      for font in Self.templateFonts {
        let template = templateImage(for: candidate, font: font)
        guard let templateVector = imageToBinaryVector(template) else { continue }

        let score = normalizedDistance(lhs: drawingVector, rhs: templateVector)
        ranked.append((char: candidate, score: score))
      }
    }

    guard ranked.isEmpty == false else { return nil }
    ranked.sort { $0.score < $1.score }

    let best = ranked[0]
    let secondBest = ranked.dropFirst().first

    // Stricter acceptance to reduce false positives:
    // 1) absolute quality
    // 2) separation from next-best candidate
    let maxAcceptedDistance = 0.44
    let minSeparation = 0.006

    guard best.score <= maxAcceptedDistance else { return nil }
    if let secondBest, (secondBest.score - best.score) < minSeparation {
      return nil
    }

    return String(best.char)
  }

  fileprivate func recognizeWithVision(strokes: [[CGPoint]], canvasSize: CGSize) async throws
    -> String?
  {
    let baseImage = drawingImage(from: strokes, canvasSize: canvasSize)
    let variants = visionInputVariants(from: baseImage)

    return try await Task.detached(priority: .userInitiated) {
      var scoreByCharacter: [String: Float] = [:]

      for (variantIndex, image) in variants.enumerated() {
        guard let cgImage = image.cgImage else { continue }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = variantIndex == 0 ? .accurate : .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        for observation in observations {
          for candidate in observation.topCandidates(10) {
            let cleaned = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let token = Self.extractSingleAlphaNumericToken(from: cleaned) else { continue }
            let weight: Float = variantIndex == 0 ? 1.0 : 0.8
            scoreByCharacter[token, default: 0] += candidate.confidence * weight
          }
        }
      }

      guard let best = scoreByCharacter.max(by: { $0.value < $1.value }),
        best.value >= 0.20
      else { return nil }

      return best.key
    }.value
  }

  fileprivate func drawingImage(from strokes: [[CGPoint]], canvasSize: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.opaque = true

    let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
    let fullImage = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: canvasSize))

      let path = UIBezierPath()
      path.lineWidth = 14
      path.lineCapStyle = .round
      path.lineJoinStyle = .round
      UIColor.black.setStroke()

      for stroke in strokes where stroke.count > 1 {
        path.removeAllPoints()
        path.move(to: stroke[0])
        for point in stroke.dropFirst() {
          path.addLine(to: point)
        }
        path.stroke()
      }
    }

    guard let bounds = drawingBounds(strokes: strokes, canvasSize: canvasSize),
      let cropped = crop(image: fullImage, to: bounds.insetBy(dx: -24, dy: -24))
    else {
      return fullImage
    }

    return cropped
  }

  fileprivate func drawingBounds(strokes: [[CGPoint]], canvasSize: CGSize) -> CGRect? {
    guard let firstPoint = strokes.first?.first else { return nil }

    var minX = firstPoint.x
    var minY = firstPoint.y
    var maxX = firstPoint.x
    var maxY = firstPoint.y

    for stroke in strokes {
      for point in stroke {
        minX = min(minX, point.x)
        minY = min(minY, point.y)
        maxX = max(maxX, point.x)
        maxY = max(maxY, point.y)
      }
    }

    let canvas = CGRect(origin: .zero, size: canvasSize)
    let raw = CGRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))
    return raw.intersection(canvas)
  }

  fileprivate func crop(image: UIImage, to rect: CGRect) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }

    let scale = image.scale
    let maxRect = CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
    let scaledRect = CGRect(
      x: rect.origin.x * scale,
      y: rect.origin.y * scale,
      width: rect.size.width * scale,
      height: rect.size.height * scale
    ).intersection(maxRect).integral

    guard scaledRect.width > 0, scaledRect.height > 0,
      let cropped = cgImage.cropping(to: scaledRect)
    else { return nil }

    return UIImage(cgImage: cropped, scale: scale, orientation: image.imageOrientation)
  }

  fileprivate func templateImage(for character: Character, font: UIFont) -> UIImage {
    let side: CGFloat = 112
    let size = CGSize(width: side, height: side)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))

      let string = String(character)
      let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.black,
      ]
      let textSize = string.size(withAttributes: attrs)
      let origin = CGPoint(
        x: (size.width - textSize.width) / 2.0,
        y: (size.height - textSize.height) / 2.0
      )
      string.draw(at: origin, withAttributes: attrs)
    }
  }

  fileprivate func imageToBinaryVector(_ image: UIImage) -> [UInt8]? {
    guard let cgImage = image.cgImage else { return nil }

    let width = Self.bitmapSize
    let height = Self.bitmapSize
    let bytesPerPixel = 1
    let bytesPerRow = width * bytesPerPixel
    var data = [UInt8](repeating: 255, count: width * height)

    guard
      let context = CGContext(
        data: &data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
      )
    else {
      return nil
    }

    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    return data.map { $0 < Self.inkThreshold ? 1 : 0 }
  }

  fileprivate func normalizedDistance(lhs: [UInt8], rhs: [UInt8]) -> Double {
    guard lhs.count == rhs.count, lhs.isEmpty == false else { return 1.0 }
    var diff = 0
    for idx in lhs.indices {
      if lhs[idx] != rhs[idx] { diff += 1 }
    }
    return Double(diff) / Double(lhs.count)
  }

  fileprivate static func extractSingleAlphaNumericToken(from raw: String) -> String? {
    let filtered =
      raw
      .filter { $0.isLetter || $0.isNumber }
    guard let first = filtered.first else { return nil }
    return String(first)
  }

  fileprivate func visionInputVariants(from image: UIImage) -> [UIImage] {
    var variants: [UIImage] = []
    variants.append(upscaled(image, side: 320))
    variants.append(highContrast(upscaled(image, side: 320)))
    variants.append(upscaled(image, side: 240))
    return variants
  }

  fileprivate func upscaled(_ image: UIImage, side: CGFloat) -> UIImage {
    let size = CGSize(width: side, height: side)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  fileprivate func highContrast(_ image: UIImage) -> UIImage {
    guard let ciImage = CIImage(image: image) else { return image }

    let controls = CIFilter(name: "CIColorControls")
    controls?.setValue(ciImage, forKey: kCIInputImageKey)
    controls?.setValue(1.25, forKey: kCIInputContrastKey)
    controls?.setValue(0.0, forKey: kCIInputSaturationKey)

    guard let output = controls?.outputImage else { return image }
    let context = CIContext(options: nil)
    guard let cg = context.createCGImage(output, from: output.extent) else { return image }
    return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
  }
}
