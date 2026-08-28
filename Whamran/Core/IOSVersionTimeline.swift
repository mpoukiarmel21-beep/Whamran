import Foundation

/// Timeline cohérente et détaillée des versions iOS (échelle 20 -> 27).
/// Chaque version est une entrée explicite avec sa date de sortie réelle,
/// reproduisant la cadence d'Apple : une majeure par an (septembre), des
/// évolutions ".x" avec patchs ".x.y" dans l'année.
public enum IOSVersionTimeline {

    /// Une version iOS avec sa date de publication.
    public struct Release {
        public let version: String
        public let date: Date
        public init(_ version: String, _ year: Int, _ month: Int, _ day: Int) {
            self.version = version
            self.date = IOSVersionTimeline.makeDate(year, month, day)
        }
    }

    public static let minMajor = 20
    public static let maxMajor = 27

    /// Catalogue explicite des versions iOS (réalistes, dans la plage de l'app).
    /// Une majeure sort chaque septembre, suivie d'évolutions mensuelles et d'un patch.
    public static let releases: [Release] = {
        var r: [Release] = []
        // (major, année de sortie de la majeure)
        let majors: [(Int, Int)] = [(20, 2019), (21, 2020), (22, 2021), (23, 2022),
                                    (24, 2023), (25, 2024), (26, 2025), (27, 2026)]
        // Décalages (mois après septembre, jour, libellé "x.y") pour les évolutions.
        let micro: [(Int, Int, String)] = [
            (0, 16, ""),      // x.0  — septembre
            (1, 12, ".1"),    // octobre
            (2, 9,  ".2"),    // novembre
            (4, 12, ".3"),    // janvier
            (5, 8,  ".4"),    // février
            (7, 12, ".5"),    // avril
            (9, 15, ".6"),    // juin
            (10, 8, ".6.1")   // juillet — patch
        ]
        for (n, y) in majors {
            for (monOff, day, suffix) in micro {
                let targetMonth = 9 + monOff
                let yy = y + (targetMonth > 12 ? 1 : 0)
                let mo = targetMonth > 12 ? targetMonth - 12 : targetMonth
                r.append(Release("\(n)\(suffix)", yy, mo, day))
            }
        }
        return r.sorted { $0.date < $1.date }
    }()

    public static func releaseDate(forVersion v: String) -> Date {
        releases.first { $0.version == v }?.date ?? makeDate(2019, 9, 16)
    }

    public static func releaseDate(forMajor major: Int) -> Date {
        releases.first { Int($0.version.split(separator: ".").first!) == major }?.date ?? makeDate(2019, 9, 16)
    }

    public static func majorOf(_ version: String) -> Int {
        Int(version.split(separator: ".").first ?? "20") ?? 20
    }

    /// Version iOS la plus récente prise en charge (aujourd'hui).
    public static var latestVersion: String {
        releases.last?.version ?? "26"
    }

    /// Aujourd'hui (date du téléphone).
    public static var today: Date { Date() }

    /// Borne basse: il y a 11 mois.
    public static var earliestAllowed: Date {
        Calendar.current.date(byAdding: .month, value: -11, to: today) ?? today
    }

    /// Borne haute: hier.
    public static var latestAllowed: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
    }

    /// Versions valides pour un modèle (dans minIOS...maxIOS) disponibles à la date donnée.
    /// Triées par date de sortie (les plus récentes d'abord).
    public static func validVersions(for date: Date, minIOS: Int, maxIOS: Int) -> [String] {
        let cappedMax = min(maxIOS, maxMajor)
        let filtered = releases.filter { r in
            let maj = majorOf(r.version)
            return maj >= minIOS && maj <= cappedMax && r.date <= date
        }
        return filtered.map { $0.version }.reversed()
    }

    /// Paire (ios, date) cohérente, iOS choisi automatiquement en fonction de la date.
    public static func randomAutoPair(minIOS: Int, maxIOS: Int) -> (ios: String, date: Date) {
        let cappedMax = min(maxIOS, maxMajor)
        let start = max(earliestAllowed, releaseDate(forMajor: minIOS))
        let range = max(0, latestAllowed.timeIntervalSince(start))
        let date = start.addingTimeInterval(Double.random(in: 0...range))
        let candidates = validVersions(for: date, minIOS: minIOS, maxIOS: cappedMax)
        // Privilégier une version proche de la date pour réalisme.
        let picked = candidates.first ?? "\(minIOS)"
        return (picked, date)
    }

    /// Date de capture cohérente avec une version iOS imposée.
    public static func randomCaptureDate(forIOS ios: String, minIOS: Int, maxIOS: Int) -> Date {
        let major = majorOf(ios)
        let effectiveMajor = min(max(major, minIOS), maxIOS)
        let effectiveIOS = major == effectiveMajor ? ios : "\(effectiveMajor)"
        let vDate = releaseDate(forVersion: effectiveIOS)
        let start = max(earliestAllowed, vDate)
        let end = latestAllowed
        if end <= start { return start }
        let range = end.timeIntervalSince(start)
        return start.addingTimeInterval(Double.random(in: 0...range))
    }

    /// Libellé lisible d'une version, ex: "iOS 26.6.1".
    public static func displayName(_ version: String) -> String {
        "iOS \(version)"
    }

    /// Sous-titre avec date de sortie, ex: "iOS 26.3 · 2 juin 2026".
    public static func subtitle(_ version: String) -> String {
        let d = releaseDate(forVersion: version)
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale.current
        return "iOS \(version) · \(f.string(from: d))"
    }

    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c) ?? Date()
    }
}
