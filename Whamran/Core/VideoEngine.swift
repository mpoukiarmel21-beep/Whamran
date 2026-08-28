import Foundation
import AVFoundation
import CoreImage

public struct GeneratedVideo {
    public let url: URL
    public let model: String
    public let iosVersion: String
    public let serial: String
    public let captureDate: Date
    public let address: String
    public let city: String
    public let country: String
    public let coordinate: (lat: Double, lon: Double)
}

public final class VideoEngine {

    private static let ciContext = CIContext()

    public static func generate(sourceURL: URL,
                                 count: Int,
                                 model: String,
                                 iosVersion: String,
                                 countryCode: String,
                                 cityName: String?,
                                 outputDir: URL,
                                 progress: ((Double) -> Void)? = nil) async throws -> [GeneratedVideo] {
        let minIOS = DeviceDatabase.all.first(where: { $0.name == model })?.minIOS ?? IOSVersionTimeline.minMajor
        let maxIOS = DeviceDatabase.all.first(where: { $0.name == model })?.maxIOS ?? IOSVersionTimeline.maxMajor
        var used = Set<String>()
        var results: [GeneratedVideo] = []

        for i in 0..<count {
            let (ios, date): (String, Date)
            if iosVersion.lowercased() == "auto" {
                let pair = IOSVersionTimeline.randomAutoPair(minIOS: minIOS, maxIOS: maxIOS)
                ios = pair.ios; date = pair.date
            } else {
                ios = iosVersion
                date = IOSVersionTimeline.randomCaptureDate(forIOS: ios, minIOS: minIOS, maxIOS: maxIOS)
            }

            let addr = LocationProvider.shared.randomAddress(countryCode: countryCode, cityName: cityName, used: &used)
            let serial = SerialGenerator.serial()

            let asset = AVURLAsset(url: sourceURL)
            let composition = AVVideoComposition(asset: asset) { request in
                var image = request.sourceImage
                // filtre léger quasi imperceptible
                guard let controls = CIFilter(name: "CIColorControls") else {
                    request.finish(with: image, context: nil); return
                }
                controls.setValue(image, forKey: kCIInputImageKey)
                controls.setValue(Double.random(in: -0.02...0.02), forKey: "inputBrightness")
                controls.setValue(1 + Double.random(in: -0.015...0.015), forKey: "inputContrast")
                controls.setValue(1 + Double.random(in: -0.01...0.01), forKey: "inputSaturation")
                if let out = controls.outputImage { image = out }
                request.finish(with: image, context: VideoEngine.ciContext)
            }

            let fileName = "whamran_\(sanitize(model))_\(ios)_\(i+1).mp4"
            let outURL = outputDir.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: outURL)

            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                throw EngineError.cannotCreateDestination
            }
            exporter.videoComposition = composition
            exporter.outputURL = outURL
            exporter.outputFileType = .mp4
            exporter.metadata = buildMetadata(model: model, ios: ios, date: date, coord: (addr.lat, addr.lon))

            await exporter.export()
            guard exporter.status == .completed else {
                throw EngineError.exportFailed(exporter.error?.localizedDescription ?? "unknown")
            }

            results.append(GeneratedVideo(url: outURL, model: model, iosVersion: ios, serial: serial,
                                           captureDate: date, address: addr.full, city: addr.cityName,
                                           country: addr.countryName, coordinate: (addr.lat, addr.lon)))
            progress?(Double(i + 1) / Double(count))
        }

        return results
    }

    private static func buildMetadata(model: String, ios: String, date: Date, coord: (lat: Double, lon: Double)) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []

        // Modèle
        items.append(makeItem(identifier: .quickTimeMetadataModel, keySpace: .quickTimeMetadata,
                               key: "com.apple.quicktime.model", value: model as NSString))
        // Logiciel / iOS
        items.append(makeItem(identifier: .quickTimeMetadataSoftware, keySpace: .quickTimeMetadata,
                               key: "com.apple.quicktime.software", value: ios as NSString))
        // Localisation ISO6709
        let iso = String(format: "%+09.4f%+010.4f/", coord.lat, coord.lon)
        items.append(makeItem(identifier: .quickTimeMetadataLocationISO6709, keySpace: .quickTimeMetadata,
                               key: "com.apple.quicktime.location.ISO6709", value: iso as NSString))
        // Date de création
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone.current
        f.formatOptions = [.withInternetDateTime]
        items.append(makeItem(identifier: .commonIdentifierCreationDate, keySpace: .common,
                               key: "creationDate", value: f.string(from: date) as NSString))
        return items
    }

    private static func makeItem(identifier: AVMetadataIdentifier, keySpace: AVMetadataKeySpace,
                                 key: String, value: NSString) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.keySpace = keySpace
        item.key = key as NSString
        item.value = value
        return item
    }

    private static func sanitize(_ s: String) -> String {
        s.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}
