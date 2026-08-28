import Foundation

/// Timeline cohérente des versions iOS (échelle 20 -> 27).
/// iOS 26 = version courante (sept 2025), iOS 27 = future (sept 2026).
public enum IOSVersionTimeline {

    /// Date de sortie publique de chaque version majeure.
    private static let majorReleaseDates: [Int: Date] = [
        20: makeDate(2019, 9, 15),
        21: makeDate(2020, 9, 15),
        22: makeDate(2021, 9, 15),
        23: makeDate(2022, 9, 15),
        24: makeDate(2023, 9, 15),
        25: makeDate(2024, 9, 15),
        26: makeDate(2025, 9, 15),
        27: makeDate(2026, 9, 14)
    ]

    public static let maxMajor = 27
    public static let minMajor = 20

    public static func releaseDate(forMajor major: Int) -> Date {
        majorReleaseDates[major] ?? makeDate(2019, 9, 15)
    }

    /// Date de sortie d'une version complète ("26.6.1").
    public static func releaseDate(forVersion version: String) -> Date {
        let parts = version.split(separator: ".").compactMap { Int($0) }
        guard let major = parts.first else { return makeDate(2019, 9, 15) }
        let base = releaseDate(forMajor: major)
        let months = (parts.count > 1 ? parts[1] : 0)
        let days = (parts.count > 2 ? parts[2] : 0)
        return Calendar.current.date(byAdding: .month, value: months, to: base)
            .flatMap { Calendar.current.date(byAdding: .day, value: days, to: $0) }
            ?? base
    }

    /// Aujourd'hui (date du téléphone).
    public static var today: Date { Date() }

    /// Borne basse: il y a 11 mois (pas plus vieux).
    public static var earliestAllowed: Date {
        Calendar.current.date(byAdding: .month, value: -11, to: today) ?? today
    }

    /// Borne haute: hier (jamais de date future).
    public static var latestAllowed: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
    }

    /// Liste des versions iOS valides pour une date et les bornes du modèle.
    public static func validVersions(for date: Date, minIOS: Int, maxIOS: Int) -> [String] {
        var result: [String] = []
        for major in minIOS...min(maxIOS, maxMajor) {
            let base = releaseDate(forMajor: major)
            guard base <= date else { continue }
            for minor in 0...6 {
                let d = Calendar.current.date(byAdding: .month, value: minor, to: base) ?? base
                guard d <= date else { break }
                let v = minor == 0 ? "\(major)" : "\(major).\(minor)"
                result.append(v)
                if minor == 6 {
                    let patch = Calendar.current.date(byAdding: .day, value: 14, to: d) ?? d
                    if patch <= date { result.append("\(major).6.1") }
                }
            }
        }
        return result
    }

    /// Paire (ios, date) cohérente, iOS choisi automatiquement.
    public static func randomAutoPair(minIOS: Int, maxIOS: Int) -> (ios: String, date: Date) {
        let start = max(earliestAllowed, releaseDate(forMajor: minIOS))
        let range = max(0, latestAllowed.timeIntervalSince(start))
        let date = start.addingTimeInterval(Double.random(in: 0...range))
        let candidates = validVersions(for: date, minIOS: minIOS, maxIOS: maxIOS)
        let ios = candidates.randomElement() ?? "\(minIOS)"
        return (ios, date)
    }

    /// Date de capture cohérente avec une version iOS imposée.
    public static func randomCaptureDate(forIOS ios: String, minIOS: Int, maxIOS: Int) -> Date {
        let parts = ios.split(separator: ".").compactMap { Int($0) }
        let major = parts.first ?? minIOS
        let effectiveMajor = min(max(major, minIOS), maxIOS)
        let effectiveIOS = major == effectiveMajor ? ios : "\(effectiveMajor)"
        let vDate = releaseDate(forVersion: effectiveIOS)
        let start = max(earliestAllowed, vDate)
        let end = latestAllowed
        if end <= start { return start }
        let range = end.timeIntervalSince(start)
        return start.addingTimeInterval(Double.random(in: 0...range))
    }

    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c) ?? Date()
    }
}
