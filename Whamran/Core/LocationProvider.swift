import Foundation

public struct City: Codable {
    public let name: String
    public let lat: Double
    public let lon: Double
    public let postal: String
}

public struct Country: Codable, Identifiable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let streetSuffix: String
    public let streets: [String]
    public let cities: [City]
}

public struct FakeAddress {
    public let full: String
    public let lat: Double
    public let lon: Double
    public let cityName: String
    public let countryName: String
    public let countryCode: String
}

public final class LocationProvider {

    public static let shared = LocationProvider()

    private let countries: [Country]

    private init() {
        guard let url = Bundle.main.url(forResource: "Locations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Country]].self, from: data) else {
            countries = []
            return
        }
        countries = decoded["countries"] ?? []
    }

    public var countryList: [Country] { countries }

    public func country(code: String) -> Country? {
        countries.first { $0.code == code }
    }

    /// Génère une adresse fictive mais située dans une vraie ville du pays.
    /// `cityName` nil = ville aléatoire dans le pays.
    public func randomAddress(countryCode: String, cityName: String? = nil, used: inout Set<String>) -> FakeAddress {
        guard let country = country(code: countryCode), let city = (cityName.flatMap { n in country.cities.first { $0.name == n } } ?? country.cities.randomElement()) else {
            // Repli sûr
            return FakeAddress(full: "Unknown", lat: 48.8566, lon: 2.3522, cityName: "Paris", countryName: "France", countryCode: "FR")
        }

        // Offset ~2 km maximum, toujours différent.
        let latOff = Double.random(in: -0.018...0.018)
        let lonScale = 1.0 / max(0.1, cos(city.lat * .pi / 180))
        let lonOff = Double.random(in: -0.018...0.018) * lonScale

        var address: FakeAddress
        var attempts = 0
        repeat {
            let street = country.streets.randomElement() ?? "Rue"
            let number = Int.random(in: 1...220)
            let cpExtra = String(format: "%02d", Int.random(in: 0...99))
            let postal = city.postal.trimmingCharacters(in: .whitespaces) + cpExtra
            let full = "\(street) \(number), \(postal) \(city.name), \(country.name)"
            let lat = city.lat + latOff
            let lon = city.lon + lonOff
            address = FakeAddress(full: full, lat: lat, lon: lon,
                                  cityName: city.name, countryName: country.name, countryCode: country.code)
            attempts += 1
        } while used.contains(address.full) && attempts < 8

        used.insert(address.full)
        return address
    }
}
