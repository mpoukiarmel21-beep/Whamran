import Foundation
import Darwin

public struct DeviceModel: Codable, Identifiable, Hashable {
    public var id: String { identifier }
    public let identifier: String
    public let name: String
    public let chip: String
    public let minIOS: Int
    public let maxIOS: Int
}

public enum DeviceDatabase {
    public static let all: [DeviceModel] = load()

    private static func load() -> [DeviceModel] {
        guard let url = Bundle.main.url(forResource: "deviceDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([DeviceModel].self, from: data) else {
            return []
        }
        return list
    }

    public static func model(for identifier: String) -> DeviceModel? {
        all.first { $0.identifier == identifier }
    }
}

public enum DeviceProfiler {
    /// Identifiant matériel réel, ex: "iPhone12,1".
    public static func currentIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    public static func currentModel() -> DeviceModel? {
        model(for: currentIdentifier())
    }

    private static func model(for identifier: String) -> DeviceModel? {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = all.first(where: { $0.identifier == id }) { return exact }
        let family = id.components(separatedBy: ",").first ?? id
        return all.first(where: { $0.identifier.hasPrefix(family + ",") })
    }

    /// Modèles compatibles = même puce que l'appareil courant.
    public static func compatibleModels(for identifier: String) -> [DeviceModel] {
        guard let current = model(for: identifier) else { return [] }
        return all.filter { $0.chip == current.chip }.sorted { $0.name < $1.name }
    }

    /// Tous les modèles groupés par puce (pour l'UI complète).
    public static func allByChip() -> [(chip: String, models: [DeviceModel])] {
        let chips = Array(Set(all.map { $0.chip })).sorted()
        return chips.map { chip in (chip, all.filter { $0.chip == chip }.sorted { $0.name < $1.name }) }
    }
}
