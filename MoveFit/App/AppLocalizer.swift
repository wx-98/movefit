import Foundation

struct AppLocalizer {
    let localeIdentifier: String
    private let languageBundle: Bundle

    init(
        language: AppLanguage,
        preferredSystemLanguage: String,
        bundle: Bundle = .main
    ) {
        localeIdentifier = language.resolvedIdentifier(
            preferredSystemLanguage: preferredSystemLanguage
        )
        if let path = bundle.path(forResource: localeIdentifier, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            languageBundle = localizedBundle
        } else {
            languageBundle = bundle
        }
    }

    func text(_ key: String) -> String {
        languageBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    func appearanceName(_ appearance: AppAppearance) -> String {
        text(appearance.rawValue)
    }

    func languageName(_ language: AppLanguage) -> String {
        text(language.rawValue)
    }

    func minutes(_ value: Int) -> String {
        formatted(value == 1 ? "duration.minute.format" : "duration.minutes.format", value)
    }

    func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: text(key),
            locale: Locale(identifier: localeIdentifier),
            arguments: arguments
        )
    }

    func duration(seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            let key: String
            switch (hours == 1, remainder == 1) {
            case (true, true): key = "home.duration.hour.minute.format"
            case (true, false): key = "home.duration.hour.minutes.format"
            case (false, true): key = "home.duration.hours.minute.format"
            case (false, false): key = "home.duration.hours.minutes.format"
            }
            return formatted(key, hours, remainder)
        }
        return self.minutes(minutes)
    }
}
