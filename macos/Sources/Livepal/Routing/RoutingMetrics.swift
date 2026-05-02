import Foundation

struct RoutingMetrics {
    var lowConfidenceEvents: Int = 0
    var reroutes: Int = 0
    var droppedPartials: Int = 0

    mutating func recordLowConfidence() { lowConfidenceEvents += 1 }
    mutating func recordReroute() { reroutes += 1 }
    mutating func recordDroppedPartial() { droppedPartials += 1 }
}
