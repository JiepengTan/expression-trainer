//
//  exp_trainerTests.swift
//  exp-trainerTests
//
//  Created by tjp on 2026/7/15.
//

import Testing
import Foundation
import SwiftData
import AVFAudio
@testable import exp_trainer

struct exp_trainerTests {

    @Test("a training lifecycle completes through the approved states")
    func trainingLifecycleCompletes() throws {
        var lifecycle = TrainingLifecycle()

        try lifecycle.transition(to: .preparing)
        try lifecycle.transition(to: .recording)
        try lifecycle.transition(to: .paused)
        try lifecycle.transition(to: .recording)
        try lifecycle.transition(to: .finishing)
        try lifecycle.transition(to: .transcriptReview)
        try lifecycle.transition(to: .completed)

        #expect(lifecycle.state == .completed)
    }

    @Test("illegal lifecycle transitions leave the state unchanged")
    func illegalLifecycleTransition() {
        var lifecycle = TrainingLifecycle()

        #expect(throws: InvalidTrainingTransition(from: .draft, to: .completed)) {
            try lifecycle.transition(to: .completed)
        }
        #expect(lifecycle.state == .draft)
    }

    @Test("metrics use effective duration and mixed-language text units")
    func objectiveMetrics() {
        let start = Date(timeIntervalSince1970: 100)
        let metrics = TrainingMetrics.calculate(
            transcript: "我爱 Swift 6，真的。",
            startedAt: start,
            endedAt: start.addingTimeInterval(40),
            pausedIntervals: [
                DateInterval(
                    start: start.addingTimeInterval(10),
                    end: start.addingTimeInterval(20)
                )
            ],
            issueCount: 2
        )

        #expect(metrics.effectiveDuration == 30)
        #expect(metrics.effectiveTextUnits == 6)
        #expect(metrics.unitsPerMinute == 12)
        #expect(metrics.issueCount == 2)
    }

    @Test("lexicon analysis prefers longest matches and persists UTF-16 ranges")
    func lexiconLongestMatch() {
        let analyzer = LexiconAnalyzer(entries: [
            LexiconEntry(term: "觉得", category: .vague, suggestions: ["判断是"]),
            LexiconEntry(term: "我觉得", category: .filler, suggestions: ["直接陈述"])
        ])

        let issues = analyzer.analyze("😀我觉得，我觉得")

        #expect(issues.map(\.matchedText) == ["我觉得", "我觉得"])
        #expect(issues.map(\.category) == [.filler, .filler])
        #expect(issues.map(\.range) == [
            UTF16TextRange(location: 2, length: 3),
            UTF16TextRange(location: 6, length: 3)
        ])
    }

    @Test("realtime feedback is gated by text, time, and duplicate windows")
    func realtimeFeedbackGate() {
        let start = Date(timeIntervalSince1970: 1_000)
        var gate = RealtimeFeedbackGate()

        #expect(!gate.shouldRequest(totalTextUnits: 39, now: start, signature: "先说结论"))
        #expect(gate.shouldRequest(totalTextUnits: 40, now: start, signature: "先说结论"))
        gate.recordRequest(totalTextUnits: 40, at: start, signature: "先说结论")

        #expect(!gate.shouldRequest(
            totalTextUnits: 80,
            now: start.addingTimeInterval(11),
            signature: "补充证据"
        ))
        #expect(!gate.shouldRequest(
            totalTextUnits: 80,
            now: start.addingTimeInterval(13),
            signature: "先说结论"
        ))
        #expect(gate.shouldRequest(
            totalTextUnits: 80,
            now: start.addingTimeInterval(13),
            signature: "补充证据"
        ))
    }

    @Test("repository persists confirmed segments and recovers unfinished sessions")
    @MainActor
    func repositoryPersistence() throws {
        let schema = Schema(VersionedSchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = SwiftDataTrainingSessionRepository(modelContext: container.mainContext)
        let session = try repository.create(
            TrainingDraft(topic: "项目复盘", goal: .conclusionFirst, targetDuration: 180, realtimeAIEnabled: false)
        )

        try repository.transition(sessionID: session.id, to: .preparing)
        try repository.appendFinalSegment(
            sessionID: session.id,
            text: "我先说结论。",
            audioRange: 0...2.4
        )

        let recovered = try repository.fetchRecoverableSessions()
        #expect(recovered.map(\.id) == [session.id])
        #expect(recovered.first?.segments.map(\.text) == ["我先说结论。"])
    }

    @Test("fake audio and speech drive the complete local training flow without AI")
    @MainActor
    func localTrainingIntegration() async throws {
        let schema = Schema(VersionedSchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = SwiftDataTrainingSessionRepository(modelContext: container.mainContext)
        let speech = FakeSpeechEngine()
        let feedback = CountingFeedbackEngine()
        let environment = AppEnvironment(
            repository: repository,
            speechRecognition: speech,
            audioCapture: FakeAudioCapture(),
            lexiconAnalyzer: LexiconAnalyzer(),
            feedback: feedback,
            permissions: GrantedPermissionService(),
            share: DefaultShareService(),
            storage: ZeroStorageService(),
            logger: SilentLogger(),
            featureFlags: .production
        )
        let session = try repository.create(
            TrainingDraft(topic: "集成测试", goal: .conclusionFirst, targetDuration: 60, realtimeAIEnabled: false)
        )
        let controller = TrainingSessionController(session: session, environment: environment)

        await controller.start()
        #expect(controller.lifecycle.state == .recording)
        await speech.emitFinal("我觉得先说结论。", range: 0...2)
        try await Task.sleep(for: .milliseconds(30))
        controller.pause()
        #expect(controller.lifecycle.state == .paused)
        controller.resume()
        await controller.finish()

        let persisted = try repository.fetchSession(id: session.id)
        #expect(controller.readyForReview)
        #expect(persisted?.state == .transcriptReview)
        #expect(persisted?.segments.map(\.text) == ["我觉得先说结论。"])
        #expect(await feedback.realtimeRequestCount() == 0)
    }
}

private actor FakeSpeechEngine: SpeechRecognitionEngine {
    private var continuation: AsyncThrowingStream<SpeechRecognitionEvent, any Error>.Continuation?

    func prepare(locale: Locale) async throws -> AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
    }

    func start() async throws -> AsyncThrowingStream<SpeechRecognitionEvent, any Error> {
        let pair = AsyncThrowingStream<SpeechRecognitionEvent, any Error>.makeStream()
        continuation = pair.continuation
        pair.continuation.yield(.ready)
        return pair.stream
    }

    func consume(_ buffer: CapturedAudioBuffer) async {}

    func finish() async throws {
        continuation?.finish()
        continuation = nil
    }

    func cancel() async {
        continuation?.finish()
        continuation = nil
    }

    func emitFinal(_ text: String, range: ClosedRange<TimeInterval>) {
        continuation?.yield(.final(text: text, audioRange: range))
    }
}

@MainActor
private final class FakeAudioCapture: AudioCaptureService {
    private var continuation: AsyncStream<AudioCaptureEvent>.Continuation?

    func start(format: AVAudioFormat) async throws -> AsyncStream<AudioCaptureEvent> {
        let pair = AsyncStream<AudioCaptureEvent>.makeStream()
        continuation = pair.continuation
        return pair.stream
    }

    func pause() throws {}
    func resume() throws {}
    func stop() {
        continuation?.finish()
        continuation = nil
    }
}

@MainActor
private final class GrantedPermissionService: PermissionService {
    func status(for permission: PermissionKind) -> PermissionState { .granted }
    func request(_ permission: PermissionKind) async -> PermissionState { .granted }
    func openSystemSettings() {}
}

private actor CountingFeedbackEngine: FeedbackEngine {
    private var count = 0

    func realtimeFeedback(for request: RealtimeFeedbackRequest) async throws -> RealtimeFeedback {
        count += 1
        return RealtimeFeedback(message: "先说结论再补证据", evidence: nil)
    }

    func report(for request: DeepReportRequest) async throws
        -> AsyncThrowingStream<ReportStreamEvent, any Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func cancelRealtimeFeedback() async {}
    func cancelReport(sessionID: UUID) async {}
    func realtimeRequestCount() -> Int { count }
}

private struct ZeroStorageService: StorageUsageService {
    func localStorageBytes() async -> Int64 { 0 }
}

private struct SilentLogger: AppLogger {
    func info(_ message: String) {}
    func error(_ message: String) {}
}
