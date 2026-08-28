import Foundation
import ImageIO
import CoreImage
import CoreGraphics
import UniformTypeIdentifiers

public struct GeneratedImage {
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

public enum EngineError: Error {
    case invalidSource
    case cannotCreateDestination
    case cannotRender
    case exportFailed(String)
}

public final class ImageMetadataEngine {

    private static let ciContext = CIContext()

    public static func generate(source: Data,
                                 count: Int,
                                 model: String,
                                 iosVersion: String,
                                 countryCode: String,
                                 cityName: String?,
                                 outputDir: URL,
                                 progress: ((Double) -> Void)? = nil) throws -> [GeneratedImage] {
        guard let src = CGImageSourceCreateWithData(source as CFData, nil) else {
            throw EngineError.invalidSource
        }
        let minIOS = DeviceDatabase.all.first(where: { $0.name == model })?.minIOS ?? IOSVersionTimeline.minMajor
        let maxIOS = DeviceDatabase.all.first(where: { $0.name == model })?.maxIOS ?? IOSVersionTimeline.maxMajor

        var used = Set<String>()
        var results: [GeneratedImage] = []
        let fileExt = "heic"

        for i in 0..<count {
            // 1. iOS + date cohérents
            let (ios, date): (String, Date)
            if iosVersion.lowercased() == "auto" {
                let pair = IOSVersionTimeline.randomAutoPair(minIOS: minIOS, maxIOS: maxIOS)
                ios = pair.ios; date = pair.date
            } else {
                ios = iosVersion
                date = IOSVersionTimeline.randomCaptureDate(forIOS: ios, minIOS: minIOS, maxIOS: maxIOS)
            }

            // 2. Localisation fictive mais réelle
            let addr = LocationProvider.shared.randomAddress(countryCode: countryCode, cityName: cityName, used: &used)
            let serial = SerialGenerator.serial()

            // 3. Nouvelle "capture" (ré-encodage + filtre quasi imperceptible)
            guard let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw EngineError.invalidSource }
            let ci = applyTinyFilter(to: CIImage(cgImage: cg), seed: i)
            guard let outCG = ciContext.createCGImage(ci, from: ci.extent) else { throw EngineError.cannotRender }

            // 4. Métadonnées fusionnées (on conserve l'existant + on modifie/ajoute)
            let base = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]) ?? [:]
            var props = base

            var tiff = (base[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
            tiff[kCGImagePropertyTIFFMake] = "Apple"
            tiff[kCGImagePropertyTIFFModel] = model
            tiff[kCGImagePropertyTIFFSoftware] = ios
            tiff[kCGImagePropertyTIFFDateTime] = exifDate(date)
            props[kCGImagePropertyTIFFDictionary] = tiff

            var exif = (base[kCGImagePropertyExifDictionary] as? [CFString: Any]) ?? [:]
            exif[kCGImagePropertyExifDateTimeOriginal] = exifDate(date)
            exif[kCGImagePropertyExifDateTimeDigitized] = exifDate(date)
            exif[kCGImagePropertyExifSubsecTimeOriginal] = String(format: "%03d", Int.random(in: 0...999))
            exif[kCGImagePropertyExifSubsecTimeDigitized] = String(format: "%03d", Int.random(in: 0...999))
            exif[kCGImagePropertyExifLensModel] = "\(model) back triple camera"
            props[kCGImagePropertyExifDictionary] = exif

            var gps: [CFString: Any] = [:]
            gps[kCGImagePropertyGPSLatitude] = abs(addr.lat)
            gps[kCGImagePropertyGPSLatitudeRef] = addr.lat >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude] = abs(addr.lon)
            gps[kCGImagePropertyGPSLongitudeRef] = addr.lon >= 0 ? "E" : "W"
            gps[kCGImagePropertyGPSDateStamp] = gpsDate(date)
            gps[kCGImagePropertyGPSProcessingMethod] = "CELLID"
            gps[kCGImagePropertyGPSAltitude] = Double.random(in: 1...120)
            props[kCGImagePropertyGPSDictionary] = gps

            var maker = (base[kCGImagePropertyMakerAppleDictionary] as? [CFString: Any]) ?? [:]
            maker["17" as CFString] = serial
            props[kCGImagePropertyMakerAppleDictionary] = maker

            // 5. Écriture
            let uti = UTType.heic.identifier as CFString
            let outData = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(outData as CFMutableData, uti, 1, nil) else {
                throw EngineError.cannotCreateDestination
            }
            CGImageDestinationSetProperties(dest, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
            CGImageDestinationAddImage(dest, outCG, props as CFDictionary)
            guard CGImageDestinationFinalize(dest) else { throw EngineError.cannotCreateDestination }

            let fileName = "whamran_\(sanitize(model))_\(ios)_\(i+1).\(fileExt)"
            let url = outputDir.appendingPathComponent(fileName)
            try outData.write(to: url)

            results.append(GeneratedImage(url: url, model: model, iosVersion: ios, serial: serial,
                                          captureDate: date, address: addr.full, city: addr.cityName,
                                          country: addr.countryName, coordinate: (addr.lat, addr.lon)))
            progress?(Double(i + 1) / Double(count))
        }

        return results
    }

    /// Filtre Core Image quasi imperceptible (±2 %), différent à chaque image.
    private static func applyTinyFilter(to image: CIImage, seed: Int) -> CIImage {
        guard let controls = CIFilter(name: "CIColorControls") else { return image }
        controls.setValue(image, forKey: kCIInputImageKey)
        controls.setValue(Double.random(in: -0.02...0.02), forKey: "inputBrightness")
        controls.setValue(1 + Double.random(in: -0.015...0.015), forKey: "inputContrast")
        controls.setValue(1 + Double.random(in: -0.01...0.01), forKey: "inputSaturation")
        guard var out = controls.outputImage else { return image }

        // Léger décalage de température (matrice couleur)
        guard let matrix = CIFilter(name: "CIColorMatrix") else { return out }
        matrix.setValue(out, forKey: kCIInputImageKey)
        let t: Double = Double.random(in: -0.02...0.02)
        matrix.setValue(CIVector(x: 1 + t, y: 0, z: 0, w: 0), forKey: "inputRVector")
        matrix.setValue(CIVector(x: 0, y: 1 - t * 0.5, z: 0, w: 0), forKey: "inputGVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 1 - t, w: 0), forKey: "inputBVector")
        if let m = matrix.outputImage { out = m }
        return out
    }

    private static func exifDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.timeZone = TimeZone.current
        return f.string(from: d)
    }

    private static func gpsDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd"
        f.timeZone = TimeZone.current
        return f.string(from: d)
    }

    private static func sanitize(_ s: String) -> String {
        s.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}
