import Foundation

enum LocaleOptions {
    /// Supported spoken languages for the two caption lanes (v1: **10** locales).
    /// Each maps to a `SFSpeechRecognizer` locale and an `NLLanguage` base code.
    static let captionLaneLocales: [(id: String, label: String)] = [
        ("en-US", "English (United States)"),
        ("es-ES", "Spanish (Spain)"),
        ("fr-FR", "French (France)"),
        ("de-DE", "German (Germany)"),
        ("it-IT", "Italian (Italy)"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ja-JP", "Japanese (Japan)"),
        ("ko-KR", "Korean (Korea)"),
        ("zh-Hans-CN", "Chinese (Simplified)"),
        ("hi-IN", "Hindi (India)"),
    ]

    static let supportedLocaleIds: Set<String> = Set(captionLaneLocales.map(\.id))

    static func shortTitle(for localeId: String) -> String {
        captionLaneLocales.first(where: { $0.id == localeId })?.label ?? localeId
    }

    /// Pick a default second lane different from `first`.
    static func defaultPairing(secondLaneIfFirstIs first: String) -> String {
        if first != "es-ES" { return "es-ES" }
        return "en-US"
    }
}
