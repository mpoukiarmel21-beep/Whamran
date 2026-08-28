import Foundation

public enum SerialGenerator {

    private static let charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    /// Numéro de série type Apple (12 caractères, sans ambiguïté).
    public static func serial() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let digits = "0123456789"
        var s = ""
        // 3 lettres (usine)
        for _ in 0..<3 { s.append(letters.randomElement()!) }
        // 2 alnum (année + semaine)
        for _ in 0..<2 { s.append(charsetChar()) }
        // 4 alnum
        for _ in 0..<4 { s.append(charsetChar()) }
        // 3 lettres
        for _ in 0..<3 { s.append(letters.randomElement()!) }
        return s
    }

    private static func charsetChar() -> Character {
        SerialGenerator.charset.randomElement()!
    }
}
