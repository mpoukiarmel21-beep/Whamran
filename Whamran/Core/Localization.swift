import Foundation

/// Langues prises en charge par l'application (FR / EN par défaut).
enum AppLanguage: String, CaseIterable, Identifiable {
    case fr = "fr"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        }
    }

    static var system: AppLanguage {
        let pref = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return pref.hasPrefix("fr") ? .fr : .en
    }

    static var current: AppLanguage {
        if let stored = UserDefaults.standard.string(forKey: AppLang.storageKey),
           let lang = AppLanguage(rawValue: stored) {
            return lang
        }
        return system
    }

    static func setCurrent(_ lang: AppLanguage) {
        UserDefaults.standard.set(lang.rawValue, forKey: AppLang.storageKey)
    }
}

enum AppLang {
    static let storageKey = "whamran_lang"

    /// Bundle localisé pour la langue sélectionnée en cours d'exécution (pas besoin de redémarrer).
    static var currentBundle: Bundle {
        guard let path = Bundle.main.path(forResource: AppLanguage.current.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    /// Fichier de chaînes d'une langue donnée.
    private static func bundle(for lang: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    /// Traduit une clé dans la langue sélectionnée (repli sur l'anglais puis sur la clé).
    static func string(_ key: String) -> String {
        let value = NSLocalizedString(key, bundle: currentBundle, comment: "")
        if value != key { return value }

        // Repli anglais si la langue courante n'est pas l'anglais.
        if AppLanguage.current != .en {
            let enValue = NSLocalizedString(key, bundle: bundle(for: .en), comment: "")
            if enValue != key { return enValue }
        }
        return key
    }

    /// Formatage avec traduction (remplace String(format: NSLocalizedString(...))).
    static func formatted(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: Locale(identifier: AppLanguage.current.rawValue), arguments: args)
    }
}
