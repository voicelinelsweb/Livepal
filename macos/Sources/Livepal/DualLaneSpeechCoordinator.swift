import AVFoundation
import Foundation
import NaturalLanguage
import Speech

@MainActor
final class DualLaneSpeechCoordinator {
    private var pipelineLane1: SpeechPipeline?
    private var pipelineLane2: SpeechPipeline?

    private let lane1NL: NLLanguage
    private let lane2NL: NLLanguage

    private var stable1: String = ""
    private var stable2: String = ""
    private var metrics = RoutingMetrics()
    private var engine = CaptionRoutingEngine()

    private var inactivityTask: Task<Void, Never>?

    init(lane1LocaleId: String, lane2LocaleId: String) throws {
        guard let nl1 = Self.nlLanguage(from: lane1LocaleId) else {
            throw NSError(domain: "Livepal", code: 40, userInfo: [NSLocalizedDescriptionKey: "Unsupported first language code"])
        }
        guard let nl2 = Self.nlLanguage(from: lane2LocaleId) else {
            throw NSError(domain: "Livepal", code: 41, userInfo: [NSLocalizedDescriptionKey: "Unsupported second language code"])
        }
        if nl1 == nl2 {
            throw NSError(domain: "Livepal", code: 42, userInfo: [NSLocalizedDescriptionKey: "Choose two different languages for the two caption sections."])
        }
        lane1NL = nl1
        lane2NL = nl2

        pipelineLane1 = try SpeechPipeline(locale: Locale(identifier: lane1LocaleId), preferOnDevice: true)
        pipelineLane2 = try SpeechPipeline(locale: Locale(identifier: lane2LocaleId), preferOnDevice: true)
    }

    func start(onVisualUpdate: @escaping (_ lane1: String, _ lane2: String, _ c1: Double, _ c2: Double) -> Void) {
        stable1 = ""
        stable2 = ""
        metrics = RoutingMetrics()
        engine = CaptionRoutingEngine()

        pipelineLane1?.start(
            onPartial: { [weak self] text in
                self?.routePartial(latest1: text, latest2: "", onVisualUpdate: onVisualUpdate)
            },
            onFinal: { [weak self] text in
                self?.routeFinal(text, fromLane: 1, onVisualUpdate: onVisualUpdate)
            }
        )

        pipelineLane2?.start(
            onPartial: { [weak self] text in
                self?.routePartial(latest1: "", latest2: text, onVisualUpdate: onVisualUpdate)
            },
            onFinal: { [weak self] text in
                self?.routeFinal(text, fromLane: 2, onVisualUpdate: onVisualUpdate)
            }
        )
    }

    func append(buffer: AVAudioPCMBuffer) {
        pipelineLane1?.append(buffer: buffer)
        pipelineLane2?.append(buffer: buffer)
    }

    func stop() {
        pipelineLane1?.stop()
        pipelineLane2?.stop()
        pipelineLane1 = nil
        pipelineLane2 = nil
        inactivityTask?.cancel()
        inactivityTask = nil
    }

    private func routePartial(
        latest1: String,
        latest2: String,
        onVisualUpdate: @escaping (String, String, Double, Double) -> Void
    ) {
        let t1 = latest1.trimmingCharacters(in: .whitespacesAndNewlines)
        let t2 = latest2.trimmingCharacters(in: .whitespacesAndNewlines)

        var candidates: [CandidateTranscript] = []
        if t1.count >= 2 {
            candidates.append(candidate(text: latest1, sourceLane: 1))
        }
        if t2.count >= 2 {
            candidates.append(candidate(text: latest2, sourceLane: 2))
        }

        let decision = engine.decide(candidates: candidates)
        if decision.activeLane == nil, !candidates.isEmpty {
            metrics.recordLowConfidence()
            if candidates.count > 1 {
                metrics.recordDroppedPartial()
            }
        }

        let display1 = decision.lane1Text.isEmpty ? stable1 : decision.lane1Text
        let display2 = decision.lane2Text.isEmpty ? stable2 : decision.lane2Text
        onVisualUpdate(display1, display2, decision.lane1Confidence, decision.lane2Confidence)

        resetInactivityTimer(onVisualUpdate: onVisualUpdate)
    }

    private func routeFinal(
        _ raw: String,
        fromLane: Int,
        onVisualUpdate: @escaping (String, String, Double, Double) -> Void
    ) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let candidate = candidate(text: trimmed, sourceLane: fromLane)
        let before = engine.lastLane
        let decision = engine.decide(candidates: [candidate])
        if before != nil, before != decision.activeLane {
            metrics.recordReroute()
        }

        if decision.activeLane == 1 {
            stable1 = trimmed
        } else if decision.activeLane == 2 {
            stable2 = trimmed
        }

        onVisualUpdate(stable1, stable2, decision.lane1Confidence, decision.lane2Confidence)
    }

    private func candidate(text: String, sourceLane: Int) -> CandidateTranscript {
        let c1 = Self.languageConfidence(text: text, language: lane1NL)
        let c2 = Self.languageConfidence(text: text, language: lane2NL)
        return CandidateTranscript(text: text, lane1Score: c1, lane2Score: c2, sourceLane: sourceLane)
    }

    private func resetInactivityTimer(onVisualUpdate: @escaping (String, String, Double, Double) -> Void) {
        inactivityTask?.cancel()
        inactivityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            onVisualUpdate(self.stable1, self.stable2, 0, 0)
        }
    }

    private static func languageConfidence(text: String, language: NLLanguage) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return 0 }
        let r = NLLanguageRecognizer()
        r.processString(trimmed)
        let h = r.languageHypotheses(withMaximum: 8)
        return h[language] ?? 0
    }

    private static func nlLanguage(from localeId: String) -> NLLanguage? {
        let base = localeId.split(separator: "-").first.map(String.init) ?? localeId
        return NLLanguage(rawValue: base)
    }
}
