#!/usr/bin/env swift

import AppKit
import CoreImage
import Foundation

let fileManager = FileManager.default
let repoRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let artifactsURL = URL(
    fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"]
        ?? repoRoot.appendingPathComponent("snapshot-artifacts", isDirectory: true).path,
    isDirectory: true
)
let referencesRootURL = repoRoot
    .appendingPathComponent("Tests", isDirectory: true)
    .appendingPathComponent("TextDiffTests", isDirectory: true)
    .appendingPathComponent("__Snapshots__", isDirectory: true)

guard fileManager.fileExists(atPath: artifactsURL.path) else {
    print("No snapshot artifacts directory found at \(artifactsURL.path)")
    exit(0)
}

let ciContext = CIContext(options: nil)
let pngExtension = "png"

func loadCIImage(from url: URL) -> CIImage? {
    guard let image = NSImage(contentsOf: url),
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
        return nil
    }
    return CIImage(bitmapImageRep: bitmap)
}

func writePNG(ciImage: CIImage, to url: URL) throws {
    let extent = ciImage.extent.integral
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let cgImage = ciContext.createCGImage(ciImage, from: extent, format: .RGBA8, colorSpace: colorSpace) else {
        throw NSError(domain: "collect_snapshot_artifacts", code: 1)
    }

    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "collect_snapshot_artifacts", code: 2)
    }
    try data.write(to: url)
}

func diffImage(referenceURL: URL, failedURL: URL) -> CIImage? {
    guard let reference = loadCIImage(from: referenceURL),
          let failed = loadCIImage(from: failedURL),
          let filter = CIFilter(name: "CIDifferenceBlendMode") else {
        return nil
    }
    filter.setValue(reference, forKey: kCIInputImageKey)
    filter.setValue(failed, forKey: kCIInputBackgroundImageKey)
    return filter.outputImage
}

let artifactFiles = fileManager.enumerator(
    at: artifactsURL,
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles]
) ?? NSEnumerator()

var enrichedCount = 0

for case let fileURL as URL in artifactFiles {
    guard fileURL.pathExtension == pngExtension else { continue }

    let relativePath = fileURL.path.replacingOccurrences(of: artifactsURL.path + "/", with: "")
    guard !relativePath.contains(".reference."),
          !relativePath.contains(".failed."),
          !relativePath.contains(".diff.") else {
        continue
    }

    let referenceURL = referencesRootURL.appendingPathComponent(relativePath)
    guard fileManager.fileExists(atPath: referenceURL.path) else {
        continue
    }

    let baseURL = fileURL.deletingPathExtension()
    let failedCopyURL = baseURL.appendingPathExtension("failed").appendingPathExtension(pngExtension)
    let referenceCopyURL = baseURL.appendingPathExtension("reference").appendingPathExtension(pngExtension)
    let diffURL = baseURL.appendingPathExtension("diff").appendingPathExtension(pngExtension)

    if !fileManager.fileExists(atPath: failedCopyURL.path) {
        try fileManager.copyItem(at: fileURL, to: failedCopyURL)
    }

    if !fileManager.fileExists(atPath: referenceCopyURL.path) {
        try fileManager.copyItem(at: referenceURL, to: referenceCopyURL)
    }

    if !fileManager.fileExists(atPath: diffURL.path),
       let diff = diffImage(referenceURL: referenceURL, failedURL: fileURL) {
        try writePNG(ciImage: diff, to: diffURL)
    }

    enrichedCount += 1
}

print("Enriched \(enrichedCount) snapshot artifact bundle(s) in \(artifactsURL.path)")
