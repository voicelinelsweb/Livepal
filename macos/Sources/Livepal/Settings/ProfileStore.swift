import Foundation

struct SessionProfile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var lane1LocaleId: String
    var lane2LocaleId: String
    var overlay: OverlayPreferences
}

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [SessionProfile] = []

    private let defaults: UserDefaults
    private let key = "livepal.sessionProfiles"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func saveProfile(name: String, lane1: String, lane2: String, overlay: OverlayPreferences) {
        let profile = SessionProfile(name: name, lane1LocaleId: lane1, lane2LocaleId: lane2, overlay: overlay)
        profiles.insert(profile, at: 0)
        persist()
    }

    func delete(_ profile: SessionProfile) {
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SessionProfile].self, from: data)
        else { return }
        profiles = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: key)
    }
}
