import AVFoundation
import Foundation
import NaturalLanguage
import Speech

/// Two `SFSpeechRecognizer` instances (one per lane language) fed the same incoming audio.
/// `NLLanguageRecognizer` scores route text into the correct section — no translation, no paid APIs.
///
/// **Turn-taking:** optimized for **one remote speaker at a time** (English, then Spanish, etc.).
/// Only one section shows a **live partial** at once; the other keeps the last **final** caption.
@MainActor
final class DualLaneSpeechCoordinator {
    private var pipelineLane1: SpeechPipeline?
    private var pipelineLane2: SpeechPipeline?

    private var latest1: String = ""
    private var latest2: String = ""

    private var stable1: String = ""
    private var stable2: String = ""
    private var partial1: String = ""
    private var partial2: String = ""

    private let lane1NL: NLLanguage
    private let lane2NL: NLLanguage

    private let confidenceFloor: Double = 0.12
    /// Minimum margin between lane scores to commit to a lane (works better when speakers take turns).
    private let sequentialMargin: Double = 0.04

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

    func start(onVisualUpdate: @escaping (_ lane1: String, _ lane2: String) -> Void) {
        latest1 = ""
        latest2 = ""
        stable1 = ""
        stable2 = ""
        partial1 = ""
        partial2 = ""

        pipelineLane1?.start(
            onPartial: { [weak self] text in
                guard let self else { return }
                self.latest1 = text
                self.routePartial(onVisualUpdate: onVisualUpdate)
            },
            onFinal: { [weak self] text in
                guard let self else { return }
                self.latest1 = text
                self.routeFinal(trimmed: text.trimmingCharacters(in: .whitespacesAndNewlines), onVisualUpdate: onVisualUpdate)
            }
        )

        pipelineLane2?.start(
            onPartial: { [weak self] text in
                guard let self else { return }
                self.latest2 = text
                self.routePartial(onVisualUpdate: onVisualUpdate)
            },
            onFinal: { [weak self] text in
                guard let self else { return }
                self.latest2 = text
                self.routeFinal(trimmed: text.trimmingCharacters(in: .whitespacesAndNewlines), onVisualUpdate: onVisualUpdate)
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
        latest1 = ""
        latest2 = ""
        stable1 = ""
        stable2 = ""
        partial1 = ""
        partial2 = ""
    }

    private func emit(onVisualUpdate: @escaping (String, String) -> Void) {
        let d1 = partial1.isEmpty ? stable1 : partial1
        let d2 = partial2.isEmpty ? stable2 : partial2
        onVisualUpdate(d1, d2)
    }

    private func routePartial(onVisualUpdate: @escaping (String, String) -> Void) {
        let t1 = latest1.trimmingCharacters(in: .whitespacesAndNewlines)
        let t2 = latest2.trimmingCharacters(in: .whitespacesAndNewlines)

        let s1_1 = Self.languageConfidence(text: t1, language: lane1NL)
        let s1_2 = Self.languageConfidence(text: t1, language: lane2NL)
        let s2_1 = Self.languageConfidence(text: t2, language: lane1NL)
        let s2_2 = Self.languageConfidence(text: t2, language: lane2NL)

        struct Scored {
            let text: String
            let c1: Double
            let c2: Double
        }

        var scored: [Scored] = []
        if t1.count >= 2 {
            scored.append(Scored(text: latest1, c1: s1_1, c2: s1_2))
        }
        if t2.count >= 2 {
            scored.append(Scored(text: latest2, c1: s2_1, c2: s2_2))
        }

        partial1 = ""
        partial2 = ""

        guard let best = scored.max(by: { max($0.c1, $0.c2) < max($1.c1, $1.c2) }) else {
            emit(onVisualUpdate: onVisualUpdate)
            return
        }

        let strength = max(best.c1, best.c2)
        guard strength >= confidenceFloor else {
            emit(onVisualUpdate: onVisualUpdate)
            return
        }

        // Turn-taking: one live partial at a time in the section that matches the detected language.
        if best.c1 >= best.c2 + sequentialMargin {
            partial1 = best.text
        } else if best.c2 >= best.c1 + sequentialMargin {
            partial2 = best.text
        } else if best.c1 >= best.c2 {
            partial1 = best.text
        } else {
            partial2 = best.text
        }

        emit(onVisualUpdate: onVisualUpdate)
    }

    private func routeFinal(trimmed: String, onVisualUpdate: @escaping (String, String) -> Void) {
        guard !trimmed.isEmpty else {
            partial1 = ""
            partial2 = ""
            emit(onVisualUpdate: onVisualUpdate)
            return
        }

        let c1 = Self.languageConfidence(text: trimmed, language: lane1NL)
        let c2 = Self.languageConfidence(text: trimmed, language: lane2NL)

        partial1 = ""
        partial2 = ""

        if c1 >= c2 + sequentialMargin, c1 >= confidenceFloor {
            stable1 = trimmed
        } else if c2 >= c1 + sequentialMargin, c2 >= confidenceFloor {
            stable2 = trimmed
        } else if c1 >= c2 {
            stable1 = trimmed
        } else {
            stable2 = trimmed
        }

        emit(onVisualUpdate: onVisualUpdate)
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
