import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case session
    case overlay
    case language
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .session: return "Session"
        case .overlay: return "Overlay"
        case .language: return "Language"
        case .advanced: return "Advanced"
        }
    }
}

struct SettingsSidebarView: View {
    @Binding var selected: SettingsSection

    var body: some View {
        List(SettingsSection.allCases, selection: $selected) { section in
            Text(section.title)
                .tag(section)
        }
        .listStyle(.sidebar)
    }
}
