import Foundation

enum TrainingGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case conclusionFirst
    case fewerFillers
    case decisiveLanguage
    case clearerExpression

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conclusionFirst: "先说结论"
        case .fewerFillers: "少说口头禅"
        case .decisiveLanguage: "不说犹豫词"
        case .clearerExpression: "表达更清晰"
        }
    }

    var symbol: String {
        switch self {
        case .conclusionFirst: "arrow.right"
        case .fewerFillers: "waveform.path"
        case .decisiveLanguage: "minus"
        case .clearerExpression: "star"
        }
    }
}

struct FeedbackEvidence: Codable, Equatable, Sendable {
    let segmentID: UUID?
    let range: UTF16TextRange?
    let quote: String
}

struct RealtimeFeedbackRequest: Codable, Equatable, Sendable {
    let sessionID: UUID
    let topic: String
    let goal: TrainingGoal
    let effectiveDuration: TimeInterval
    let incrementalTranscript: String
    let localIssueCounts: [ExpressionIssueCategory: Int]
}

struct RealtimeFeedback: Codable, Equatable, Sendable {
    let message: String
    let evidence: FeedbackEvidence?
}

enum ReportGenerationStatus: String, Codable, CaseIterable, Sendable {
    case localOnly
    case queued
    case generating
    case completed
    case failed
}

struct ReportDimension: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
}

struct RewriteComparison: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let original: String
    let revised: String
    let reason: String
}

struct AITrainingReport: Codable, Equatable, Sendable {
    let diagnosis: String
    let strengths: [FeedbackEvidence]
    let problems: [FeedbackEvidence]
    let rewrites: [RewriteComparison]
    let dimensions: [ReportDimension]
    let nextFocus: String
}

struct DeepReportRequest: Codable, Equatable, Sendable {
    let sessionID: UUID
    let topic: String
    let goal: TrainingGoal
    let transcriptVersion: Int
    let transcript: String
    let objectiveMetrics: TrainingMetrics
    let localIssues: [ExpressionIssue]
}

enum ReportStreamEvent: Equatable, Sendable {
    case progress(Double, String)
    case partial(AITrainingReport)
    case completed(AITrainingReport)
    case failed(String)
}

struct RealtimeFeedbackGate: Equatable, Sendable {
    private(set) var lastRequestedTextUnits = 0
    private(set) var lastRequestAt: Date?
    private var signatures: [String: Date] = [:]

    let minimumNewTextUnits: Int
    let minimumInterval: TimeInterval
    let duplicateWindow: TimeInterval

    init(
        minimumNewTextUnits: Int = 40,
        minimumInterval: TimeInterval = 12,
        duplicateWindow: TimeInterval = 60
    ) {
        self.minimumNewTextUnits = minimumNewTextUnits
        self.minimumInterval = minimumInterval
        self.duplicateWindow = duplicateWindow
    }

    func shouldRequest(totalTextUnits: Int, now: Date, signature: String) -> Bool {
        guard totalTextUnits - lastRequestedTextUnits >= minimumNewTextUnits else { return false }
        if let lastRequestAt, now.timeIntervalSince(lastRequestAt) < minimumInterval {
            return false
        }
        if let duplicateAt = signatures[signature], now.timeIntervalSince(duplicateAt) < duplicateWindow {
            return false
        }
        return true
    }

    mutating func recordRequest(totalTextUnits: Int, at date: Date, signature: String) {
        lastRequestedTextUnits = totalTextUnits
        lastRequestAt = date
        signatures = signatures.filter { date.timeIntervalSince($0.value) < duplicateWindow }
        signatures[signature] = date
    }
}
