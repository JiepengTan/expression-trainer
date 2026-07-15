import Foundation
import SwiftData

struct TrainingDraft: Equatable, Sendable {
    var topic: String
    var goal: TrainingGoal
    var targetDuration: TimeInterval
    var realtimeAIEnabled: Bool

    static let defaultDraft = TrainingDraft(
        topic: "",
        goal: .conclusionFirst,
        targetDuration: 180,
        realtimeAIEnabled: false
    )
}

@Model
final class TrainingSessionRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var topic: String
    var goalRawValue: String
    var targetDuration: TimeInterval
    var effectiveDuration: TimeInterval
    var stateRawValue: String
    var realtimeAIEnabled: Bool
    var transcriptVersion: Int
    var effectiveTextUnits: Int
    var unitsPerMinute: Double?
    var issueCount: Int
    var nextFocus: String
    var reportStatusRawValue: String

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegmentRecord.session)
    var segments: [TranscriptSegmentRecord]
    @Relationship(deleteRule: .cascade, inverse: \ExpressionIssueRecord.session)
    var issues: [ExpressionIssueRecord]
    @Relationship(deleteRule: .cascade, inverse: \FeedbackItemRecord.session)
    var feedbackItems: [FeedbackItemRecord]
    @Relationship(deleteRule: .cascade, inverse: \TrainingReportRecord.session)
    var reports: [TrainingReportRecord]

    var goal: TrainingGoal {
        get { TrainingGoal(rawValue: goalRawValue) ?? .conclusionFirst }
        set { goalRawValue = newValue.rawValue }
    }

    var state: TrainingState {
        get { TrainingState(rawValue: stateRawValue) ?? .draft }
        set { stateRawValue = newValue.rawValue }
    }

    var reportStatus: ReportGenerationStatus {
        get { ReportGenerationStatus(rawValue: reportStatusRawValue) ?? .localOnly }
        set { reportStatusRawValue = newValue.rawValue }
    }

    var confirmedTranscript: String {
        segments.sorted { $0.order < $1.order }.map(\.text).joined(separator: "\n")
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        topic: String,
        goal: TrainingGoal,
        targetDuration: TimeInterval,
        realtimeAIEnabled: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.topic = topic
        goalRawValue = goal.rawValue
        self.targetDuration = targetDuration
        effectiveDuration = 0
        stateRawValue = TrainingState.draft.rawValue
        self.realtimeAIEnabled = realtimeAIEnabled
        transcriptVersion = 1
        effectiveTextUnits = 0
        issueCount = 0
        nextFocus = goal.title
        reportStatusRawValue = ReportGenerationStatus.localOnly.rawValue
        segments = []
        issues = []
        feedbackItems = []
        reports = []
    }
}

@Model
final class TranscriptSegmentRecord {
    @Attribute(.unique) var id: UUID
    var order: Int
    var text: String
    var audioStart: TimeInterval
    var audioEnd: TimeInterval
    var isUserEdited: Bool
    var createdAt: Date
    var session: TrainingSessionRecord?

    init(
        id: UUID = UUID(),
        order: Int,
        text: String,
        audioStart: TimeInterval,
        audioEnd: TimeInterval,
        isUserEdited: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.order = order
        self.text = text
        self.audioStart = audioStart
        self.audioEnd = audioEnd
        self.isUserEdited = isUserEdited
        self.createdAt = createdAt
    }
}

@Model
final class ExpressionIssueRecord {
    @Attribute(.unique) var id: UUID
    var categoryRawValue: String
    var matchedText: String
    var utf16Location: Int
    var utf16Length: Int
    var suggestions: [String]
    var segmentID: UUID?
    var session: TrainingSessionRecord?

    var category: ExpressionIssueCategory {
        ExpressionIssueCategory(rawValue: categoryRawValue) ?? .clarity
    }

    init(issue: ExpressionIssue) {
        id = issue.id
        categoryRawValue = issue.category.rawValue
        matchedText = issue.matchedText
        utf16Location = issue.range.location
        utf16Length = issue.range.length
        suggestions = issue.suggestions
        segmentID = issue.segmentID
    }
}

enum FeedbackSource: String, Codable, Sendable {
    case local
    case ai
}

@Model
final class FeedbackItemRecord {
    @Attribute(.unique) var id: UUID
    var sourceRawValue: String
    var kind: String
    var message: String
    var createdAt: Date
    var segmentID: UUID?
    var isStale: Bool
    var session: TrainingSessionRecord?

    init(
        id: UUID = UUID(),
        source: FeedbackSource,
        kind: String,
        message: String,
        createdAt: Date = .now,
        segmentID: UUID? = nil,
        isStale: Bool = false
    ) {
        self.id = id
        sourceRawValue = source.rawValue
        self.kind = kind
        self.message = message
        self.createdAt = createdAt
        self.segmentID = segmentID
        self.isStale = isStale
    }
}

@Model
final class TrainingReportRecord {
    @Attribute(.unique) var id: UUID
    var transcriptVersion: Int
    var statusRawValue: String
    var structuredData: Data?
    var modelName: String?
    var modelVersion: String?
    var errorMessage: String?
    var generatedAt: Date?
    var session: TrainingSessionRecord?

    init(
        id: UUID = UUID(),
        transcriptVersion: Int,
        status: ReportGenerationStatus = .queued
    ) {
        self.id = id
        self.transcriptVersion = transcriptVersion
        statusRawValue = status.rawValue
    }

    var decodedReport: AITrainingReport? {
        guard let structuredData else { return nil }
        return try? JSONDecoder().decode(AITrainingReport.self, from: structuredData)
    }
}

enum VersionedSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [
            TrainingSessionRecord.self,
            TranscriptSegmentRecord.self,
            ExpressionIssueRecord.self,
            FeedbackItemRecord.self,
            TrainingReportRecord.self
        ]
    }
}
