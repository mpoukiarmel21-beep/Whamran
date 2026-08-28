import Foundation

/// "Caméra virtuelle" : reproduit les réglages réels d'une capture par iPhone.
/// Simule la puce / génération de capteur du modèle simulé et génère des valeurs
/// d'exposition réalistes (focale, ouverture, vitesse, ISO, objectif) utilisées
/// pour écrire les métadonnées EXIF, afin que le fichier soit lu comme une vraie
/// photo d'appareil et jamais comme une capture d'écran.
public struct VirtualCamera {
    public let model: String
    public let ios: String
    public let make = "Apple"
    public let lensMake = "Apple"
    public let lensModel: String
    public let focalLength: Double
    public let fNumber: Double
    public let exposureTime: Double
    public let iso: Double
    public let brightness: Double
    public let aperture: String
    public let whiteBalance = 0
    public let flash = 16                 // Flash n'a pas déclenché
    public let colorSpace = 1            // sRGB
    public let meteringMode = 5          // "Pattern"
    public let sensingMethod = 2         // One-chip color area
    public let exposureProgram = 2       // Programme normal
    public let isoSpeedRating: Double
    public let subjectDistance: Double
    public let focalLength35mm: Double

    public init(model: String, ios: String) {
        self.model = model
        self.ios = ios

        // Génération de la caméra (arrière triple/pro) selon la puce.
        let generation = Self.cameraGeneration(for: model)

        switch generation {
        case 1: // grand-angle base
            lensModel = "\(model) back dual wide camera"
            focalLength = 4.2
            fNumber = 1.8
            focalLength35mm = 26
        case 2:
            lensModel = "\(model) back triple wide camera"
            focalLength = 4.25
            fNumber = 1.6
            focalLength35mm = 24
        case 3:
            lensModel = "\(model) back triple wide camera"
            focalLength = 4.3
            fNumber = 1.5
            focalLength35mm = 24
        default: // 4 = dernière génération
            lensModel = "\(model) back triple camera"
            focalLength = 4.35
            fNumber = 1.5
            focalLength35mm = 24
        }

        // Exposition réaliste (lumière extérieure/intérieure)
        let daylight = Bool.random()
        exposureTime = daylight ? Double.random(in: 0.0008...0.0020) : Double.random(in: 0.010...0.060)
        isoSpeedRating = daylight ? Double.random(in: 50...125) : Double.random(in: 250...800)
        iso = isoSpeedRating
        brightness = daylight ? Double.random(in: 4.0...8.0) : Double.random(in: 2.0...4.5)
        subjectDistance = Double.random(in: 1.0...15.0)
        aperture = String(format: "%.1f", fNumber)
    }

    /// 1 = ancien grand-angle, 2 = triple gén1, 3 = triple gén2, 4 = dernière gén.
    private static func cameraGeneration(for model: String) -> Int {
        let lower = model.lowercased()
        if lower.contains("17") || lower.contains("18") || lower.contains("19") { return 4 }
        if lower.contains("16") || lower.contains("15") || lower.contains("14") { return 3 }
        if lower.contains("13") || lower.contains("12") || lower.contains("11") { return 2 }
        return 1
    }
}
