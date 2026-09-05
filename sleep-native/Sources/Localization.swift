import Foundation

enum L10n {
    static var language: AppLanguage = .system
    static var code: String {
        if language != .system { return language.rawValue }
        return Locale.preferredLanguages.first?.hasPrefix("es") == true ? "es" : "en"
    }
    static var locale: Locale { Locale(identifier: code == "es" ? "es_ES" : "en_GB") }
    static func text(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
func L(_ key: String) -> String { L10n.text(key) }
func LF(_ key: String, _ values: CVarArg...) -> String { String(format: L(key), locale: L10n.locale, arguments: values) }
