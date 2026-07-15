import Foundation
import Observation

@MainActor
@Observable
final class TrainingSessionController {
    let sessionID: UUID
    let topic: String
    let goal: TrainingGoal
    let targetDuration: TimeInterval
    let realtimeAIEnabled: Bool

    private(set) var lifecycle: TrainingLifecycle
    private(set) var elapsed: TimeInterval = 0
    private(set) var partialTranscript = ""
    private(set) var confirmedSegments: [String]
    private(set) var issues: [ExpressionIssue] = []
    private(set) var currentHint: String
    private(set) var isPreparing = false
    private(set) var readyForReview = false
    var errorMessage: String?
    var interruptionCanResume: Bool?

    private let environment: AppEnvironment
    private let previewFrozen: Bool
    private var startedAt: Date?
    private var pauseBeganAt: Date?
    private var pausedIntervals: [DateInterval] = []
    private var finalKeys: Set<String> = []
    private var feedbackGate = RealtimeFeedbackGate()
    private var lastFeedbackMessage: String?

    @ObservationIgnored private var speechTask: Task<Void, Never>?
    @ObservationIgnored private var audioTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    init(session: TrainingSessionRecord, environment: AppEnvironment, previewFrozen: Bool = false) {
        sessionID = session.id
        topic = session.topic
        goal = session.goal
        targetDuration = session.targetDuration
        realtimeAIEnabled = session.realtimeAIEnabled
        lifecycle = TrainingLifecycle(state: session.state)
        confirmedSegments = session.segments.sorted { $0.order < $1.order }.map(\.text)
        currentHint = session.nextFocus.isEmpty ? session.goal.title : session.nextFocus
        startedAt = session.startedAt
        self.environment = environment
        self.previewFrozen = previewFrozen
    }

    deinit {
        speechTask?.cancel()
        audioTask?.cancel()
        timerTask?.cancel()
        feedbackTask?.cancel()
    }

    func start() async {
        guard !previewFrozen else { return }
        guard !isPreparing, lifecycle.state != .recording else { return }
        isPreparing = true
        errorMessage = nil
        do {
            guard await requestRequiredPermissions() else {
                throw ServiceError.unavailable("需要麦克风与语音识别权限才能开始训练。")
            }
            if lifecycle.state == .draft {
                try environment.repository.transition(sessionID: sessionID, to: .preparing)
                try lifecycle.transition(to: .preparing)
            }

            let format = try await environment.speechRecognition.prepare(
                locale: Locale(identifier: "zh-CN")
            )
            let recognitionEvents = try await environment.speechRecognition.start()
            let audioEvents = try await environment.audioCapture.start(format: format)

            if lifecycle.state == .preparing {
                try environment.repository.transition(sessionID: sessionID, to: .recording)
                try lifecycle.transition(to: .recording)
            } else if lifecycle.state == .interrupted || lifecycle.state == .paused {
                try environment.repository.transition(sessionID: sessionID, to: .recording)
                try lifecycle.transition(to: .recording)
            }
            startedAt = startedAt ?? .now
            isPreparing = false
            startEventTasks(recognitionEvents: recognitionEvents, audioEvents: audioEvents)
        } catch {
            isPreparing = false
            errorMessage = error.localizedDescription
            environment.logger.error("Training start failed: \(error.localizedDescription)")
        }
    }

    func pause() {
        guard lifecycle.state == .recording else { return }
        do {
            try environment.audioCapture.pause()
            try environment.repository.transition(sessionID: sessionID, to: .paused)
            try lifecycle.transition(to: .paused)
            pauseBeganAt = .now
        } catch {
            errorMessage = "暂停失败：\(error.localizedDescription)"
        }
    }

    func resume() {
        guard lifecycle.state == .paused else { return }
        do {
            try environment.audioCapture.resume()
            if let pauseBeganAt {
                pausedIntervals.append(DateInterval(start: pauseBeganAt, end: .now))
            }
            pauseBeganAt = nil
            try environment.repository.transition(sessionID: sessionID, to: .recording)
            try lifecycle.transition(to: .recording)
        } catch {
            errorMessage = "继续录音失败：\(error.localizedDescription)"
        }
    }

    func finish() async {
        guard lifecycle.state == .recording || lifecycle.state == .paused else { return }
        if let pauseBeganAt {
            pausedIntervals.append(DateInterval(start: pauseBeganAt, end: .now))
            self.pauseBeganAt = nil
        }
        do {
            try environment.repository.transition(sessionID: sessionID, to: .finishing)
            try lifecycle.transition(to: .finishing)
            timerTask?.cancel()
            environment.audioCapture.stop()
            try await environment.speechRecognition.finish()
            await speechTask?.value
            try persistObjectiveMetrics(endedAt: .now)
            try environment.repository.transition(sessionID: sessionID, to: .transcriptReview)
            try lifecycle.transition(to: .transcriptReview)
            readyForReview = true
        } catch {
            errorMessage = "结束训练失败：\(error.localizedDescription)"
        }
    }

    func resumeAfterInterruption() {
        guard lifecycle.state == .interrupted else { return }
        interruptionCanResume = nil
        do {
            try environment.audioCapture.resume()
            try environment.repository.transition(sessionID: sessionID, to: .recording)
            try lifecycle.transition(to: .recording)
        } catch {
            errorMessage = "恢复录音失败：\(error.localizedDescription)"
        }
    }

    func finishAfterInterruption() async {
        guard lifecycle.state == .interrupted else { return }
        interruptionCanResume = nil
        environment.audioCapture.stop()
        do {
            try await environment.speechRecognition.finish()
            await speechTask?.value
            try persistObjectiveMetrics(endedAt: .now)
            try environment.repository.transition(sessionID: sessionID, to: .transcriptReview)
            try lifecycle.transition(to: .transcriptReview)
            readyForReview = true
        } catch {
            errorMessage = "保存训练失败：\(error.localizedDescription)"
        }
    }

    func abandon() async {
        environment.audioCapture.stop()
        await environment.speechRecognition.cancel()
        try? environment.repository.transition(sessionID: sessionID, to: .abandoned)
        try? lifecycle.transition(to: .abandoned)
    }

    private func requestRequiredPermissions() async -> Bool {
        for permission in PermissionKind.allCases {
            let state = environment.permissions.status(for: permission)
            let finalState = state == .notDetermined
                ? await environment.permissions.request(permission)
                : state
            if finalState != .granted { return false }
        }
        return true
    }

    private func startEventTasks(
        recognitionEvents: AsyncThrowingStream<SpeechRecognitionEvent, any Error>,
        audioEvents: AsyncStream<AudioCaptureEvent>
    ) {
        speechTask = Task { [weak self] in
            do {
                for try await event in recognitionEvents {
                    guard let self else { return }
                    handleRecognitionEvent(event)
                }
            } catch is CancellationError {
            } catch {
                self?.errorMessage = "语音识别中断：\(error.localizedDescription)"
            }
        }
        audioTask = Task { [weak self] in
            for await event in audioEvents {
                guard let self else { return }
                await handleAudioEvent(event)
            }
        }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self else { return }
                updateElapsed()
            }
        }
    }

    private func handleRecognitionEvent(_ event: SpeechRecognitionEvent) {
        switch event {
        case .partial(let text, _):
            partialTranscript = text
        case .final(let text, let audioRange):
            let key = "\(audioRange.lowerBound)-\(audioRange.upperBound)-\(text)"
            guard finalKeys.insert(key).inserted else { return }
            partialTranscript = ""
            confirmedSegments.append(text)
            do {
                try environment.repository.appendFinalSegment(
                    sessionID: sessionID,
                    text: text,
                    audioRange: audioRange
                )
                issues = environment.lexiconAnalyzer.analyze(confirmedSegments.joined(separator: "\n"))
                requestRealtimeFeedbackIfNeeded()
            } catch {
                errorMessage = "字幕保存失败"
            }
        case .failed(let message):
            errorMessage = "语音识别失败：\(message)"
        case .resourceProgress, .ready:
            break
        }
    }

    private func handleAudioEvent(_ event: AudioCaptureEvent) async {
        switch event {
        case .buffer(let buffer):
            if lifecycle.state == .recording {
                await environment.speechRecognition.consume(buffer)
            }
        case .interrupted(let canResume):
            guard lifecycle.state == .recording || lifecycle.state == .paused else { return }
            try? environment.repository.transition(sessionID: sessionID, to: .interrupted)
            try? lifecycle.transition(to: .interrupted)
            interruptionCanResume = canResume
        case .routeChanged:
            environment.logger.info("Audio route changed")
        case .failed(let message):
            errorMessage = message
        }
    }

    private func updateElapsed(now: Date = .now) {
        guard let startedAt else { return }
        var intervals = pausedIntervals
        if let pauseBeganAt { intervals.append(DateInterval(start: pauseBeganAt, end: now)) }
        elapsed = TrainingMetrics.calculate(
            transcript: "",
            startedAt: startedAt,
            endedAt: now,
            pausedIntervals: intervals,
            issueCount: 0
        ).effectiveDuration
    }

    private func persistObjectiveMetrics(endedAt: Date) throws {
        guard let startedAt else { return }
        let transcript = confirmedSegments.joined(separator: "\n")
        issues = environment.lexiconAnalyzer.analyze(transcript)
        let metrics = TrainingMetrics.calculate(
            transcript: transcript,
            startedAt: startedAt,
            endedAt: endedAt,
            pausedIntervals: pausedIntervals,
            issueCount: issues.count
        )
        elapsed = metrics.effectiveDuration
        try environment.repository.updateMetrics(sessionID: sessionID, metrics: metrics)
    }

    private func requestRealtimeFeedbackIfNeeded() {
        guard realtimeAIEnabled else { return }
        let transcript = confirmedSegments.joined(separator: "\n")
        let units = TextUnitCounter.count(in: transcript)
        let signature = String(transcript.suffix(80))
        let now = Date.now
        guard feedbackGate.shouldRequest(
            totalTextUnits: units,
            now: now,
            signature: signature
        ) else { return }
        feedbackGate.recordRequest(totalTextUnits: units, at: now, signature: signature)
        let counts = Dictionary(grouping: issues, by: \.category).mapValues(\.count)
        let request = RealtimeFeedbackRequest(
            sessionID: sessionID,
            topic: topic,
            goal: goal,
            effectiveDuration: elapsed,
            incrementalTranscript: String(transcript.suffix(160)),
            localIssueCounts: counts
        )
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                let feedback = try await environment.feedback.realtimeFeedback(for: request)
                guard !Task.isCancelled, feedback.message != lastFeedbackMessage else { return }
                currentHint = feedback.message
                lastFeedbackMessage = feedback.message
            } catch is CancellationError {
            } catch {
                environment.logger.info("Realtime AI unavailable; local training continues")
            }
        }
    }
}
