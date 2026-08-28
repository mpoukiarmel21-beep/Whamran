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
                                 city: WorldCity?,
                                 outputDir: URL,
                                 progress: ((Double) -> Void)? = nil,
                                 maxDimension: CGFloat? = nil) throws -> [GeneratedImage] {
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

            // 2. Localisation: la ville sélectionnée agit réellement sur la photo.
            //    Si aucune ville choisie -> emplacement aléatoire dans le monde entier.
            let worldCity = city ?? LocationProvider.shared.randomWorldCity()
            let addr = LocationProvider.shared.address(forWorld: worldCity, used: &used)
            let serial = SerialGenerator.serial()

            // 3. Caméra virtuelle: réglages EXIF réalistes propres au modèle simulé.
            let camera = VirtualCamera(model: model, ios: ios)

            // 4. "Capture" réelle: recadrage très léger + filtre quasi imperceptible + ré-encodage HEIC.
            guard let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw EngineError.invalidSource }
            var base = CIImage(cgImage: cg)
            if let maxDimension = maxDimension { base = resize(base, maxDimension: maxDimension) }
            let ci = applySubtleChanges(to: base, seed: i)
            let outData = try renderToHEIC(ci: ci, camera: camera, date: date, addr: addr, serial: serial)

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

    /// Convertit une image de caméra / une frame vidéo en "véritable capture de caméra" (HEIC + EXIF complet).
    /// Utilisée par le studio vidéo (photos en direct + extraction auto de N frames).
    public static func generateFrame(cg: CGImage,
                                     index: Int,
                                     model: String,
                                     iosVersion: String,
                                     city: WorldCity?,
                                     outputDir: URL,
                                     used: inout Set<String>,
                                     maxDimension: CGFloat? = nil) throws -> GeneratedImage {
        let minIOS = DeviceDatabase.all.first(where: { $0.name == model })?.minIOS ?? IOSVersionTimeline.minMajor
        let maxIOS = DeviceDatabase.all.first(where: { $0.name == model })?.maxIOS ?? IOSVersionTimeline.maxMajor

        let (ios, date): (String, Date)
        if iosVersion.lowercased() == "auto" {
            let pair = IOSVersionTimeline.randomAutoPair(minIOS: minIOS, maxIOS: maxIOS)
            ios = pair.ios; date = pair.date
        } else {
            ios = iosVersion
            date = IOSVersionTimeline.randomCaptureDate(forIOS: ios, minIOS: minIOS, maxIOS: maxIOS)
        }

        let worldCity = city ?? LocationProvider.shared.randomWorldCity()
        let addr = LocationProvider.shared.address(forWorld: worldCity, used: &used)
        let serial = SerialGenerator.serial()
        let camera = VirtualCamera(model: model, ios: ios)

        var base = CIImage(cgImage: cg)
        if let maxDimension = maxDimension { base = resize(base, maxDimension: maxDimension) }
        let ci = applySubtleChanges(to: base, seed: index)
        let outData = try renderToHEIC(ci: ci, camera: camera, date: date, addr: addr, serial: serial)

        let fileName = "whamran_\(sanitize(model))_\(ios)_\(index+1).heic"
        let url = outputDir.appendingPathComponent(fileName)
        try outData.write(to: url)

        return GeneratedImage(url: url, model: model, iosVersion: ios, serial: serial,
                              captureDate: date, address: addr.full, city: addr.cityName,
                              country: addr.countryName, coordinate: (addr.lat, addr.lon))
    }

    /// Rendu HEIC avec les métadonnées EXIF/GPS caméra complètes.
    private static func renderToHEIC(ci: CIImage,
                                     camera: VirtualCamera,
                                     date: Date,
                                     addr: FakeAddress,
                                     serial: String) throws -> Data {
        // 5. Métadonnées complètes de caméra (jamais "capture d'écran").
        var props: [CFString: Any] = [:]
        let width = ci.extent.width
        let height = ci.extent.height

        var tiff: [CFString: Any] = [:]
        tiff[kCGImagePropertyTIFFMake] = camera.make
        tiff[kCGImagePropertyTIFFModel] = camera.model
        tiff[kCGImagePropertyTIFFSoftware] = camera.ios
        tiff[kCGImagePropertyTIFFDateTime] = exifDate(date)
        tiff[kCGImagePropertyTIFFOrientation] = 1
        tiff[kCGImagePropertyTIFFResolutionUnit] = 2
        props[kCGImagePropertyTIFFDictionary] = tiff

        var exif: [CFString: Any] = [:]
        exif[kCGImagePropertyExifDateTimeOriginal] = exifDate(date)
        exif[kCGImagePropertyExifDateTimeDigitized] = exifDate(date)
        exif[kCGImagePropertyExifSubsecTimeOriginal] = String(format: "%03d", Int.random(in: 0...999))
        exif[kCGImagePropertyExifSubsecTimeDigitized] = String(format: "%03d", Int.random(in: 0...999))
        exif[kCGImagePropertyExifExposureTime] = camera.exposureTime
        exif[kCGImagePropertyExifFNumber] = camera.fNumber
        exif[kCGImagePropertyExifExposureProgram] = camera.exposureProgram
        exif[kCGImagePropertyExifISOSpeedRatings] = [Int(camera.isoSpeedRating)]
        exif[kCGImagePropertyExifComponentsConfiguration] = Data([1, 2, 3, 0])
        exif[kCGImagePropertyExifBrightnessValue] = camera.brightness
        exif[kCGImagePropertyExifExposureBiasValue] = 0.0
        exif[kCGImagePropertyExifMeteringMode] = camera.meteringMode
        exif[kCGImagePropertyExifFlash] = camera.flash
        exif[kCGImagePropertyExifFocalLength] = camera.focalLength
        exif[kCGImagePropertyExifSubjectArea] = [1400, 1050, 200, 200]
        exif[kCGImagePropertyExifColorSpace] = camera.colorSpace
        exif[kCGImagePropertyExifPixelXDimension] = width
        exif[kCGImagePropertyExifPixelYDimension] = height
        exif[kCGImagePropertyExifSensingMethod] = camera.sensingMethod
        exif[kCGImagePropertyExifSceneType] = 1
        exif[kCGImagePropertyExifLensMake] = camera.lensMake
        exif[kCGImagePropertyExifLensModel] = camera.lensModel
        exif[kCGImagePropertyExifLensSpecification] = [camera.focalLength, camera.focalLength, camera.fNumber, camera.fNumber]
        exif[kCGImagePropertyExifSubjectDistance] = camera.subjectDistance
        props[kCGImagePropertyExifDictionary] = exif

        var gps: [CFString: Any] = [:]
        gps[kCGImagePropertyGPSLatitude] = abs(addr.lat)
        gps[kCGImagePropertyGPSLatitudeRef] = addr.lat >= 0 ? "N" : "S"
        gps[kCGImagePropertyGPSLongitude] = abs(addr.lon)
        gps[kCGImagePropertyGPSLongitudeRef] = addr.lon >= 0 ? "E" : "W"
        gps[kCGImagePropertyGPSAltitude] = Double.random(in: 1...120)
        gps[kCGImagePropertyGPSDateStamp] = gpsDate(date)
        gps[kCGImagePropertyGPSTimeStamp] = gpsTime(date)
        gps[kCGImagePropertyGPSSatellites] = String(format: "%02d", Int.random(in: 6...15))
        gps[kCGImagePropertyGPSHPositioningError] = Double.random(in: 3...12)
        props[kCGImagePropertyGPSDictionary] = gps

        var maker: [CFString: Any] = [:]
        maker["17" as CFString] = serial
        props[kCGImagePropertyMakerAppleDictionary] = maker

        // 6. Écriture HEIC (encodage natif, comme la caméra).
        let uti = UTType.heic.identifier as CFString
        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(outData as CFMutableData, uti, 1, nil) else {
            throw EngineError.cannotCreateDestination
        }
        CGImageDestinationSetProperties(dest, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard let outCG = ciContext.createCGImage(ci, from: ci.extent) else { throw EngineError.cannotRender }
        CGImageDestinationAddImage(dest, outCG, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw EngineError.cannotCreateDestination }
        return outData as Data
    }

    /// Redimensionne proportionnellement pour que le grand côté ne dépasse pas `maxDimension`.
    /// Utilisé par le studio vidéo pour produire des photos plus petites (réaliste pour des frames).
    private static func resize(_ input: CIImage, maxDimension: CGFloat) -> CIImage {
        let w = input.extent.width
        let h = input.extent.height
        guard w > 0, h > 0 else { return input }
        let maxSide = max(w, h)
        guard maxSide > maxDimension else { return input }
        let scale = maxDimension / maxSide
        if let lanczos = CIFilter(name: "CILanczosScaleTransform") {
            lanczos.setValue(input, forKey: kCIInputImageKey)
            lanczos.setValue(scale, forKey: kCIInputScaleKey)
            lanczos.setValue(1.0, forKey: kCIInputAspectRatioKey)
            if let o = lanczos.outputImage { return o }
        }
        return input
    }

    /// Recadrage léger (0-3%) + filtre Core Image quasi imperceptible, différent à chaque image.
    private static func applySubtleChanges(to input: CIImage, seed: Int) -> CIImage {
        let extent = input.extent
        // Recadrage très subtil (0...3% de chaque côté) puis recentrage.
        let crop = CGFloat.random(in: 0.0...0.03)
        let w = extent.width * (1 - crop * 2)
        let h = extent.height * (1 - crop * 2)
        let ox = extent.origin.x + extent.width * crop
        let oy = extent.origin.y + extent.height * crop
        let cropped = input.cropped(to: CGRect(x: ox, y: oy, width: w, height: h))
            .transformed(by: CGAffineTransform(translationX: -ox, y: -oy))

        var out = cropped
        // Filtre quasi invisible: très légers contrastes/luminosité/saturation.
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(out, forKey: kCIInputImageKey)
            controls.setValue(Double.random(in: -0.02...0.02), forKey: "inputBrightness")
            controls.setValue(1 + Double.random(in: -0.02...0.02), forKey: "inputContrast")
            controls.setValue(1 + Double.random(in: -0.015...0.015), forKey: "inputSaturation")
            if let o = controls.outputImage { out = o }
        }

        // Léger décalage de température (matrice couleur), quasi invisible.
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(out, forKey: kCIInputImageKey)
            let t = Double.random(in: -0.025...0.025)
            matrix.setValue(CIVector(x: 1 + t, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: 1 - t * 0.5, z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 1 - t, w: 0), forKey: "inputBVector")
            if let m = matrix.outputImage { out = m }
        }
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

    private static func gpsTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = TimeZone.current
        return f.string(from: d)
    }

    private static func sanitize(_ s: String) -> String {
        s.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}
