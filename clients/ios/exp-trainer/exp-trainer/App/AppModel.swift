import Foundation
import Observation

enum RootTab: Hashable {
    case training
    case history
}

enum AppRoute: Hashable {
    case settings
    case training(UUID)
    case transcriptReview(UUID)
    case report(UUID)
}

enum AppOverlay: Identifiable, Equatable {
    case permissionDenied
    case speechPreparing
    case speechUnavailable(String)
    case abandonTraining(UUID)
    case interrupted(canResume: Bool)
    case restoreDraft(UUID)
    case confirmDelete(UUID)
    case confirmDeleteAll
    case aiConsent

    var id: String {
        switch self {
        case .permissionDenied: "permissionDenied"
        case .speechPreparing: "speechPreparing"
        case .speechUnavailable: "speechUnavailable"
        case .abandonTraining(let id): "abandon-\(id)"
        case .interrupted: "interrupted"
        case .restoreDraft(let id): "restoreDraft-\(id)"
        case .confirmDelete(let id): "delete-\(id)"
        case .confirmDeleteAll: "deleteAll"
        case .aiConsent: "aiConsent"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let environment: AppEnvironment
    var hasCompletedOnboarding: Bool
    var onboardingPage = 0
    var selectedTab: RootTab = .training
    var routes: [AppRoute] = []
    var presentedTrainingDraft: TrainingDraft?
    var sessions: [TrainingSessionRecord] = []
    var activeTraining: TrainingSessionController?
    var overlay: AppOverlay?
    var toast: String?

    var defaultGoal: TrainingGoal {
        didSet { defaults.set(defaultGoal.rawValue, forKey: Keys.defaultGoal) }
    }
    var defaultDuration: TimeInterval {
        didSet { defaults.set(defaultDuration, forKey: Keys.defaultDuration) }
    }
    var realtimeAIEnabled: Bool {
        didSet { defaults.set(realtimeAIEnabled, forKey: Keys.realtimeAIEnabled) }
    }
    private(set) var hasConsentedToAI: Bool

    private let defaults: UserDefaults

    init(environment: AppEnvironment, defaults: UserDefaults = .standard) {
        self.environment = environment
        self.defaults = defaults
        let arguments = ProcessInfo.processInfo.arguments
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingComplete)
            || arguments.contains("-skip-onboarding")
        defaultGoal = TrainingGoal(
            rawValue: defaults.string(forKey: Keys.defaultGoal) ?? ""
        ) ?? .conclusionFirst
        let savedDuration = defaults.double(forKey: Keys.defaultDuration)
        defaultDuration = savedDuration > 0 ? savedDuration : 180
        realtimeAIEnabled = defaults.bool(forKey: Keys.realtimeAIEnabled)
        hasConsentedToAI = defaults.bool(forKey: Keys.aiConsent)
        reload()
        applyLaunchScenarioIfPresent()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboardingComplete)
    }

    func reload() {
        do {
            sessions = try environment.repository.fetchAll()
            let isShowingTraining = routes.contains {
                if case .training = $0 { return true }
                return false
            }
            if activeTraining == nil,
               !isShowingTraining,
               let draft = try environment.repository.fetchRecoverableSessions().first,
               overlay == nil {
                overlay = .restoreDraft(draft.id)
            }
        } catch {
            environment.logger.error("Failed to load local sessions: \(error.localizedDescription)")
            toast = "本地记录加载失败"
        }
    }

    func presentNewTraining(prefill session: TrainingSessionRecord? = nil) {
        presentedTrainingDraft = TrainingDraft(
            topic: session?.topic ?? "",
            goal: session?.goal ?? defaultGoal,
            targetDuration: session?.targetDuration ?? defaultDuration,
            realtimeAIEnabled: realtimeAIEnabled && hasConsentedToAI
        )
    }

    func requestAIConsent() {
        overlay = .aiConsent
    }

    func acceptAIConsent() {
        hasConsentedToAI = true
        defaults.set(true, forKey: Keys.aiConsent)
        realtimeAIEnabled = true
        overlay = nil
    }

    func beginTraining(_ draft: TrainingDraft) {
        do {
            let session = try environment.repository.create(draft)
            let controller = TrainingSessionController(session: session, environment: environment)
            activeTraining = controller
            presentedTrainingDraft = nil
            routes.append(.training(session.id))
            reloadWithoutRecoveryPrompt()
        } catch {
            toast = "无法创建训练：\(error.localizedDescription)"
        }
    }

    func resumeTraining(sessionID: UUID) {
        guard let session = try? environment.repository.fetchSession(id: sessionID) else { return }
        activeTraining = TrainingSessionController(session: session, environment: environment)
        overlay = nil
        routes.append(.training(sessionID))
    }

    func reviewTranscript(sessionID: UUID) {
        if routes.last == .training(sessionID) { routes.removeLast() }
        routes.append(.transcriptReview(sessionID))
        reloadWithoutRecoveryPrompt()
    }

    func showReport(sessionID: UUID) {
        if routes.last == .transcriptReview(sessionID) { routes.removeLast() }
        routes.append(.report(sessionID))
        reloadWithoutRecoveryPrompt()
    }

    func delete(sessionID: UUID) {
        do {
            try environment.repository.delete(sessionID: sessionID)
            overlay = nil
            reloadWithoutRecoveryPrompt()
        } catch {
            toast = "删除失败"
        }
    }

    func deleteAll() {
        do {
            try environment.repository.deleteAll()
            overlay = nil
            reloadWithoutRecoveryPrompt()
        } catch {
            toast = "清除失败"
        }
    }

    func session(id: UUID) -> TrainingSessionRecord? {
        try? environment.repository.fetchSession(id: id)
    }

    private func reloadWithoutRecoveryPrompt() {
        do { sessions = try environment.repository.fetchAll() }
        catch { environment.logger.error("Failed to refresh local sessions") }
    }

    private enum Keys {
        static let onboardingComplete = "onboarding.complete"
        static let defaultGoal = "training.defaultGoal"
        static let defaultDuration = "training.defaultDuration"
        static let realtimeAIEnabled = "ai.realtime.enabled"
        static let aiConsent = "ai.consent.accepted"
    }

    private func applyLaunchScenarioIfPresent() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let marker = arguments.firstIndex(of: "-ui-state"),
              arguments.indices.contains(marker + 1),
              let scenario = UITestScenario(rawValue: arguments[marker + 1]) else { return }
        try? environment.repository.deleteAll()
        sessions = []
        overlay = nil
        routes = []
        presentedTrainingDraft = nil

        switch scenario {
        case .onboarding1, .onboarding2, .onboarding3:
            hasCompletedOnboarding = false
            onboardingPage = scenario == .onboarding1 ? 0 : (scenario == .onboarding2 ? 1 : 2)
        case .homeEmpty:
            hasCompletedOnboarding = true
        case .homeReturning:
            hasCompletedOnboarding = true
            _ = try? seedCompletedSession()
        case .newTraining:
            hasCompletedOnboarding = true
            presentedTrainingDraft = .defaultDraft
        case .trainingRecording, .trainingPaused, .trainingFinishing:
            hasCompletedOnboarding = true
            if let session = try? seedLiveSession(for: scenario) {
                activeTraining = TrainingSessionController(
                    session: session,
                    environment: environment,
                    previewFrozen: true
                )
                routes = [.training(session.id)]
            }
        case .transcriptReview:
            hasCompletedOnboarding = true
            if let session = try? seedReviewSession() { routes = [.transcriptReview(session.id)] }
        case .reportLocal, .reportAILoading, .reportAIComplete:
            hasCompletedOnboarding = true
            if let session = try? seedCompletedSession() {
                if scenario == .reportAILoading {
                    try? environment.repository.updateReport(
                        sessionID: session.id,
                        transcriptVersion: session.transcriptVersion,
                        status: .generating,
                        report: nil,
                        errorMessage: nil
                    )
                } else if scenario == .reportAIComplete {
                    try? environment.repository.updateReport(
                        sessionID: session.id,
                        transcriptVersion: session.transcriptVersion,
                        status: .completed,
                        report: Self.sampleAIReport,
                        errorMessage: nil
                    )
                }
                routes = [.report(session.id)]
            }
        case .historyEmpty:
            hasCompletedOnboarding = true
            selectedTab = .history
        case .historyList:
            hasCompletedOnboarding = true
            _ = try? seedCompletedSession()
            selectedTab = .history
        case .settings:
            hasCompletedOnboarding = true
            routes = [.settings]
        case .overlayPermission:
            hasCompletedOnboarding = true
            overlay = .permissionDenied
        case .overlaySpeechPreparing:
            hasCompletedOnboarding = true
            overlay = .speechPreparing
        case .overlayInterruption:
            hasCompletedOnboarding = true
            overlay = .interrupted(canResume: true)
        case .overlayAbandon:
            hasCompletedOnboarding = true
            if let session = try? seedLiveSession(for: .trainingRecording) {
                overlay = .abandonTraining(session.id)
            }
        case .overlayDelete:
            hasCompletedOnboarding = true
            if let session = try? seedCompletedSession() { overlay = .confirmDelete(session.id) }
        }
        reloadWithoutRecoveryPrompt()
    }

    private func seedLiveSession(for scenario: UITestScenario) throws -> TrainingSessionRecord {
        let session = try environment.repository.create(
            TrainingDraft(topic: "季度项目复盘", goal: .conclusionFirst, targetDuration: 180, realtimeAIEnabled: false)
        )
        try environment.repository.transition(sessionID: session.id, to: .preparing)
        try environment.repository.transition(sessionID: session.id, to: .recording)
        try environment.repository.appendFinalSegment(
            sessionID: session.id,
            text: "我先说结论，这个方案应该优先做。",
            audioRange: 0...3.2
        )
        if scenario == .trainingPaused {
            try environment.repository.transition(sessionID: session.id, to: .paused)
        } else if scenario == .trainingFinishing {
            try environment.repository.transition(sessionID: session.id, to: .finishing)
        }
        return session
    }

    private func seedReviewSession() throws -> TrainingSessionRecord {
        let session = try seedLiveSession(for: .trainingFinishing)
        try environment.repository.transition(sessionID: session.id, to: .transcriptReview)
        return session
    }

    private func seedCompletedSession() throws -> TrainingSessionRecord {
        let session = try seedReviewSession()
        let transcript = session.confirmedTranscript
        let issues = environment.lexiconAnalyzer.analyze(transcript)
        try environment.repository.replaceTranscript(sessionID: session.id, text: transcript, issues: issues)
        let start = Date(timeIntervalSince1970: 0)
        let metrics = TrainingMetrics.calculate(
            transcript: transcript,
            startedAt: start,
            endedAt: start.addingTimeInterval(78),
            pausedIntervals: [],
            issueCount: issues.count
        )
        try environment.repository.updateMetrics(sessionID: session.id, metrics: metrics)
        try environment.repository.transition(sessionID: session.id, to: .completed)
        sessions = try environment.repository.fetchAll()
        return session
    }

    private static let sampleAIReport = AITrainingReport(
        diagnosis: "结论已经出现，但证据可以更早、更具体地跟上。",
        strengths: [FeedbackEvidence(segmentID: nil, range: nil, quote: "我先说结论")],
        problems: [FeedbackEvidence(segmentID: nil, range: nil, quote: "这个方案应该")],
        rewrites: [
            RewriteComparison(
                id: UUID(),
                original: "这个方案应该优先做。",
                revised: "我建议本周优先完成这个方案。",
                reason: "补充主语和时间边界，让判断更明确。"
            )
        ],
        dimensions: [ReportDimension(id: "clarity", title: "清晰度", summary: "结论明确，证据仍可具体。")],
        nextFocus: "结论后立刻补一条证据"
    )
}

enum UITestScenario: String, CaseIterable {
    case onboarding1 = "onboarding-1"
    case onboarding2 = "onboarding-2"
    case onboarding3 = "onboarding-3"
    case homeEmpty = "home-empty"
    case homeReturning = "home-returning"
    case newTraining = "new-training"
    case trainingRecording = "training-recording"
    case trainingPaused = "training-paused"
    case trainingFinishing = "training-finishing"
    case transcriptReview = "transcript-review"
    case reportLocal = "report-local"
    case reportAILoading = "report-ai-loading"
    case reportAIComplete = "report-ai-complete"
    case historyEmpty = "history-empty"
    case historyList = "history-list"
    case settings
    case overlayPermission = "overlay-permission"
    case overlaySpeechPreparing = "overlay-speech-preparing"
    case overlayInterruption = "overlay-interruption"
    case overlayAbandon = "overlay-abandon"
    case overlayDelete = "overlay-delete"
}
