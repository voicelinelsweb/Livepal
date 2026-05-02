import Foundation

@MainActor
final class CaptionContentModel: ObservableObject {
    @Published var lane1Title: String = ""
    @Published var lane2Title: String = ""
    @Published var lane1Line: String = ""
    @Published var lane2Line: String = ""
}
