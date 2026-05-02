import CoreGraphics
import Foundation

enum HUDVerticalAnchor: String, CaseIterable, Identifiable, Codable {
    case top
    case middle
    case bottom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: return "Top"
        case .middle: return "Middle"
        case .bottom: return "Bottom"
        }
    }
}

struct OverlayPreferences: Codable, Equatable {
    var width: Double = 980
    var height: Double = 240
    var opacity: Double = 0.82
    var fontSize: Double = 30
    var anchor: HUDVerticalAnchor = .middle

    static let storageKey = "livepal.overlayPreferences"

    static func load(from defaults: UserDefaults) -> OverlayPreferences {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OverlayPreferences.self, from: data)
        else { return OverlayPreferences() }
        return decoded
    }

    func persist(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
