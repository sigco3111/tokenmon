import AppKit
import Foundation
import SwiftUI

enum TokenmonFieldSpriteVariant: String {
    case grasslandTuft = "grassland_tuft.png"
    case skyCloud = "sky_cloud.png"
    case coastWave = "coast_wave.png"
    case iceSnowflake = "ice_snowflake.png"
}

@MainActor
enum TokenmonFieldSpriteLoader {
    private static var cache: [String: NSImage] = [:]
    private static let popoverBackgroundPrefix = "popover-background:"

    static func image(field: TokenmonSceneFieldKind, variant: TokenmonFieldSpriteVariant) -> NSImage? {
        let cacheKey = "\(field.rawValue):\(variant.rawValue)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = spriteURL(field: field, variant: variant),
              let sourceImage = NSImage(contentsOf: url) else {
            return nil
        }

        let image = trimmedImage(sourceImage) ?? sourceImage
        cache[cacheKey] = image
        return image
    }

    static func popoverBackgroundImage(field: TokenmonSceneFieldKind) -> NSImage? {
        let cacheKey = "\(popoverBackgroundPrefix)\(field.rawValue)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = popoverBackgroundURL(field: field),
              let sourceImage = NSImage(contentsOf: url) else {
            return nil
        }

        let image = trimmedImage(sourceImage) ?? sourceImage
        cache[cacheKey] = image
        return image
    }

    private static func spriteURL(field: TokenmonSceneFieldKind, variant: TokenmonFieldSpriteVariant) -> URL? {
        let relative = "assets/sprites/fields/\(field.rawValue)/\(variant.rawValue)"
        let fm = FileManager.default

        let cwdURL = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(relative)
        if fm.fileExists(atPath: cwdURL.path) {
            return cwdURL
        }

        if let executableURL = Bundle.main.executableURL {
            var candidate = executableURL.deletingLastPathComponent()
            for _ in 0..<8 {
                let url = candidate.appendingPathComponent(relative)
                if fm.fileExists(atPath: url.path) {
                    return url
                }
                candidate.deleteLastPathComponent()
            }
        }

        if let bundled = TokenmonAppResourceLocator.resourceURL(
            relativePath: "sprites/fields/\(field.rawValue)/\(variant.rawValue)"
        ) {
            return bundled
        }

        return nil
    }

    private static func popoverBackgroundURL(field: TokenmonSceneFieldKind) -> URL? {
        let relative: String
        switch field {
        case .coast:
            relative = "assets/backgrounds/popover/coast/variant-3.png"
        case .grassland:
            relative = "assets/backgrounds/popover/grassland/variant-2.png"
        case .ice:
            relative = "assets/backgrounds/popover/ice/variant-2.png"
        case .sky:
            relative = "assets/backgrounds/popover/sky/variant-4.png"
        default:
            return nil
        }

        let fm = FileManager.default
        let cwdURL = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(relative)
        if fm.fileExists(atPath: cwdURL.path) {
            return cwdURL
        }

        if let executableURL = Bundle.main.executableURL {
            var candidate = executableURL.deletingLastPathComponent()
            for _ in 0..<8 {
                let url = candidate.appendingPathComponent(relative)
                if fm.fileExists(atPath: url.path) {
                    return url
                }
                candidate.deleteLastPathComponent()
            }
        }

        if let bundled = TokenmonAppResourceLocator.resourceURL(
            relativePath: "backgrounds/popover/\(field.rawValue)/variant-3.png"
        ) {
            return bundled
        }

        return nil
    }

    private static func trimmedImage(_ image: NSImage) -> NSImage? {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let trimmedRect = nonTransparentBounds(in: bitmap)
        else {
            return nil
        }

        guard
            let cgImage = bitmap.cgImage,
            let croppedCGImage = cgImage.cropping(to: trimmedRect)
        else {
            return nil
        }

        let cropped = NSBitmapImageRep(cgImage: croppedCGImage)
        let result = NSImage(size: NSSize(width: cropped.pixelsWide, height: cropped.pixelsHigh))
        result.addRepresentation(cropped)
        return result
    }

    private static func nonTransparentBounds(in bitmap: NSBitmapImageRep) -> NSRect? {
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.01 else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        return NSRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }
}

struct TokenmonFieldSpriteImage: View {
    let field: TokenmonSceneFieldKind
    let variant: TokenmonFieldSpriteVariant

    var body: some View {
        if let image = TokenmonFieldSpriteLoader.image(field: field, variant: variant) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
        }
    }
}
