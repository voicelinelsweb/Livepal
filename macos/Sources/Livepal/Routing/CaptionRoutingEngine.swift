import Foundation

struct CaptionRouteDecision {
    var lane1Text: String = ""
    var lane2Text: String = ""
    var lane1Confidence: Double = 0
    var lane2Confidence: Double = 0
    var activeLane: Int? = nil
}

struct CandidateTranscript {
    let text: String
    let lane1Score: Double
    let lane2Score: Double
    let sourceLane: Int
}

struct CaptionRoutingEngine {
    var confidenceFloor: Double = 0.12
    var laneMargin: Double = 0.05
    var rerouteDebounceMs: Int = 350

    private(set) var lastLane: Int?
    private(set) var lastSwitchAt: Date = .distantPast

    mutating func decide(candidates: [CandidateTranscript], now: Date = Date()) -> CaptionRouteDecision {
        guard let best = candidates.max(by: { max($0.lane1Score, $0.lane2Score) < max($1.lane1Score, $1.lane2Score) }) else {
            return CaptionRouteDecision()
        }

        let strongest = max(best.lane1Score, best.lane2Score)
        guard strongest >= confidenceFloor else {
            return CaptionRouteDecision(activeLane: lastLane)
        }

        var targetLane = 1
        if best.lane2Score > best.lane1Score + laneMargin {
            targetLane = 2
        }

        if let previous = lastLane, previous != targetLane {
            let elapsed = now.timeIntervalSince(lastSwitchAt) * 1000
            if elapsed < Double(rerouteDebounceMs) {
                targetLane = previous
            }
        }

        if lastLane != targetLane {
            lastSwitchAt = now
        }
        lastLane = targetLane

        if targetLane == 1 {
            return CaptionRouteDecision(
                lane1Text: best.text,
                lane2Text: "",
                lane1Confidence: best.lane1Score,
                lane2Confidence: best.lane2Score,
                activeLane: 1
            )
        }

        return CaptionRouteDecision(
            lane1Text: "",
            lane2Text: best.text,
            lane1Confidence: best.lane1Score,
            lane2Confidence: best.lane2Score,
            activeLane: 2
        )
    }
}
