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

/// Ville mondiale (issue de WorldCities.json), recherchable.
public struct WorldCity: Codable, Identifiable, Equatable {
    public var id: String { "\(name)|\(country)|\(lat)|\(lon)" }
    public let name: String
    public let country: String
    public let code: String
    public let lat: Double
    public let lon: Double
    public var display: String { "\(name), \(country)" }
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
    private let world: [WorldCity]

    private init() {
        // Pays avec rues / codes postaux pour générer des adresses réalistes.
        var loadedCountries: [Country] = []
        if let url = Bundle.main.url(forResource: "Locations", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: [Country]].self, from: data) {
            loadedCountries = decoded["countries"] ?? []
        }
        countries = loadedCountries

        // Villes mondiales pour la recherche globale.
        var loadedWorld: [WorldCity] = []
        if let url = Bundle.main.url(forResource: "WorldCities", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: [WorldCity]].self, from: data) {
            loadedWorld = decoded["cities"] ?? []
        }
        world = loadedWorld
    }

    public var countryList: [Country] { countries }

    public var worldCities: [WorldCity] { world }

    /// Ville mondiale aléatoire (pour le mode "Aléatoire dans le monde").
    public func randomWorldCity() -> WorldCity {
        world.randomElement() ?? WorldCity(name: "Paris", country: "France", code: "FR", lat: 48.8566, lon: 2.3522)
    }


    public func country(code: String) -> Country? {
        countries.first { $0.code == code }
    }

    /// Recherche mondiale de villes (nom ou pays), insensible à la casse.
    public func searchCities(query: String, limit: Int = 30) -> [WorldCity] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let lowered = q.lowercased()
        return world.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.country.lowercased().contains(lowered)
        }
        .prefix(limit)
        .map { $0 }
    }

    /// Adresse fictive située dans la ville du monde sélectionnée (ou aléatoire).
    /// Chaque appel renvoie une adresse ET un point GPS différents (dans la même ville).
    public func address(forWorld city: WorldCity, used: inout Set<String>) -> FakeAddress {
        let country = country(code: city.code)
        let streets: [String] = country?.streets ?? ["Main Street", "Rue de la Ville", "Avenue Centrale", "Calle Mayor", "Bahnhofstrasse"]
        // Décalage GPS visible mais toujours dans la ville (échelle ~quelques km).
        let jitterLat = Double.random(in: -0.045...0.045)
        let lonScale = 1.0 / max(0.1, cos(city.lat * .pi / 180))
        let jitterLon = Double.random(in: -0.045...0.045) * lonScale
        let lat = city.lat + jitterLat
        let lon = city.lon + jitterLon

        var full = ""
        var attempts = 0
        repeat {
            let street = streets.randomElement() ?? "Main Street"
            let number = Int.random(in: 1...220)
            full = "\(street) \(number), \(city.name), \(city.country)"
            attempts += 1
        } while used.contains(full) && attempts < 12

        used.insert(full)
        return FakeAddress(full: full, lat: lat, lon: lon, cityName: city.name,
                           countryName: city.country, countryCode: city.code)
    }

    /// Adresse fictive dans une ville du catalogue de pays (repli / auto).
    public func randomAddress(countryCode: String, cityName: String? = nil, used: inout Set<String>) -> FakeAddress {
        guard let country = country(code: countryCode), let city = (cityName.flatMap { n in country.cities.first { $0.name == n } } ?? country.cities.randomElement()) else {
            return FakeAddress(full: "Unknown", lat: 48.8566, lon: 2.3522, cityName: "Paris", countryName: "France", countryCode: "FR")
        }
        let latOff = Double.random(in: -0.018...0.018)
        let lonScale = 1.0 / max(0.1, cos(city.lat * .pi / 180))
        let lonOff = Double.random(in: -0.018...0.018) * lonScale
        var full = ""
        var attempts = 0
        repeat {
            let street = country.streets.randomElement() ?? "Rue"
            let number = Int.random(in: 1...220)
            let cpExtra = String(format: "%02d", Int.random(in: 0...99))
            let postal = city.postal.trimmingCharacters(in: .whitespaces) + cpExtra
            full = "\(street) \(number), \(postal) \(city.name), \(country.name)"
            attempts += 1
        } while used.contains(full) && attempts < 8
        used.insert(full)
        return FakeAddress(full: full, lat: city.lat + latOff, lon: city.lon + lonOff,
                           cityName: city.name, countryName: country.name, countryCode: country.code)
    }
}
