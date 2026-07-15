import Foundation
import SwiftData

@MainActor
protocol TrainingSessionRepository: AnyObject {
    func create(_ draft: TrainingDraft) throws -> TrainingSessionRecord
    func transition(sessionID: UUID, to state: TrainingState) throws
    func appendFinalSegment(sessionID: UUID, text: String, audioRange: ClosedRange<TimeInterval>) throws
    func replaceTranscript(sessionID: UUID, text: String, issues: [ExpressionIssue]) throws
    func updateMetrics(sessionID: UUID, metrics: TrainingMetrics) throws
    func updateReport(
        sessionID: UUID,
        transcriptVersion: Int,
        status: ReportGenerationStatus,
        report: AITrainingReport?,
        errorMessage: String?
    ) throws
    func fetchSession(id: UUID) throws -> TrainingSessionRecord?
    func fetchAll() throws -> [TrainingSessionRecord]
    func fetchRecoverableSessions() throws -> [TrainingSessionRecord]
    func delete(sessionID: UUID) throws
    func deleteAll() throws
}

@MainActor
final class SwiftDataTrainingSessionRepository: TrainingSessionRepository {
    private let modelContext: ModelContext
    private let now: @MainActor () -> Date

    init(modelContext: ModelContext, now: @escaping @MainActor () -> Date = { .now }) {
        self.modelContext = modelContext
        self.now = now
    }

    func create(_ draft: TrainingDraft) throws -> TrainingSessionRecord {
        let session = TrainingSessionRecord(
            createdAt: now(),
            topic: draft.topic.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: draft.goal,
            targetDuration: max(30, draft.targetDuration),
            realtimeAIEnabled: draft.realtimeAIEnabled
        )
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    func transition(sessionID: UUID, to state: TrainingState) throws {
        guard let session = try fetchSession(id: sessionID) else { throw RepositoryError.notFound }
        var lifecycle = TrainingLifecycle(state: session.state)
        try lifecycle.transition(to: state)
        session.state = lifecycle.state
        if state == .recording, session.startedAt == nil { session.startedAt = now() }
        if state == .completed || state == .abandoned { session.endedAt = now() }
        try modelContext.save()
    }

    func appendFinalSegment(
        sessionID: UUID,
        text: String,
        audioRange: ClosedRange<TimeInterval>
    ) throws {
        guard let session = try fetchSession(id: sessionID) else { throw RepositoryError.notFound }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let segment = TranscriptSegmentRecord(
            order: (session.segments.map(\.order).max() ?? -1) + 1,
            text: trimmed,
            audioStart: max(0, audioRange.lowerBound),
            audioEnd: max(audioRange.lowerBound, audioRange.upperBound)
        )
        segment.session = session
        modelContext.insert(segment)
        session.segments.append(segment)
        try modelContext.save()
    }

    func replaceTranscript(sessionID: UUID, text: String, issues: [ExpressionIssue]) throws {
        guard let session = try fetchSession(id: sessionID) else { throw RepositoryError.notFound }
        session.segments.forEach(modelContext.delete)
        session.issues.forEach(modelContext.delete)
        session.segments.removeAll()
        session.issues.removeAll()

        let segment = TranscriptSegmentRecord(
            order: 0,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            audioStart: 0,
            audioEnd: session.effectiveDuration,
            isUserEdited: true
        )
        segment.session = session
        modelContext.insert(segment)
        session.segments.append(segment)

        for issue in issues {
            let record = ExpressionIssueRecord(issue: issue)
            record.session = session
            modelContext.insert(record)
            session.issues.append(record)
        }
        session.transcriptVersion += 1
        session.issueCount = issues.count
        session.reports.forEach { $0.statusRawValue = ReportGenerationStatus.localOnly.rawValue }
        try modelContext.save()
    }

    func updateMetrics(sessionID: UUID, metrics: TrainingMetrics) throws {
        guard let session = try fetchSession(id: sessionID) else { throw RepositoryError.notFound }
        session.effectiveDuration = metrics.effectiveDuration
        session.effectiveTextUnits = metrics.effectiveTextUnits
        session.unitsPerMinute = metrics.unitsPerMinute
        session.issueCount = metrics.issueCount
        try modelContext.save()
    }

    func updateReport(
        sessionID: UUID,
        transcriptVersion: Int,
        status: ReportGenerationStatus,
        report: AITrainingReport?,
        errorMessage: String?
    ) throws {
        guard let session = try fetchSession(id: sessionID) else { throw RepositoryError.notFound }
        let record: TrainingReportRecord
        if let existing = session.reports.first(where: { $0.transcriptVersion == transcriptVersion }) {
            record = existing
        } else {
            record = TrainingReportRecord(transcriptVersion: transcriptVersion, status: status)
            record.session = session
            modelContext.insert(record)
            session.reports.append(record)
        }
        record.statusRawValue = status.rawValue
        record.structuredData = try report.map { try JSONEncoder().encode($0) }
        record.errorMessage = errorMessage
        record.generatedAt = status == .completed ? now() : nil
        session.reportStatus = status
        if let nextFocus = report?.nextFocus, !nextFocus.isEmpty {
            session.nextFocus = nextFocus
        }
        try modelContext.save()
    }

    func fetchSession(id: UUID) throws -> TrainingSessionRecord? {
        try modelContext.fetch(FetchDescriptor<TrainingSessionRecord>()).first { $0.id == id }
    }

    func fetchAll() throws -> [TrainingSessionRecord] {
        try modelContext.fetch(FetchDescriptor<TrainingSessionRecord>())
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchRecoverableSessions() throws -> [TrainingSessionRecord] {
        try fetchAll().filter { $0.state != .completed && $0.state != .abandoned }
    }

    func delete(sessionID: UUID) throws {
        guard let session = try fetchSession(id: sessionID) else { return }
        modelContext.delete(session)
        try modelContext.save()
    }

    func deleteAll() throws {
        for session in try fetchAll() { modelContext.delete(session) }
        try modelContext.save()
    }
}

enum RepositoryError: Error, Equatable {
    case notFound
}
