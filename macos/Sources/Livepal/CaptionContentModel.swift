import Foundation

@MainActor
final class CaptionContentModel: ObservableObject {
    @Published var lane1Title: String = ""
    @Published var lane2Title: String = ""
    @Published var lane1Line: String = ""
    @Published var lane2Line: String = ""
    @Published var lane1Confidence: Double = 0
    @Published var lane2Confidence: Double = 0
    @Published var fontSize: Double = 30
    @Published var panelOpacity: Double = 0.82
}
