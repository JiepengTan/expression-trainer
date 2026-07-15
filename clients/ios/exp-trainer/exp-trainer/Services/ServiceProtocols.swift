import AVFAudio
import Foundation

struct CapturedAudioBuffer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let timestamp: TimeInterval
}

enum AudioCaptureEvent: Sendable {
    case buffer(CapturedAudioBuffer)
    case interrupted(canResume: Bool)
    case routeChanged
    case failed(String)
}

enum SpeechRecognitionEvent: Equatable, Sendable {
    case resourceProgress(Double)
    case ready
    case partial(text: String, audioRange: ClosedRange<TimeInterval>)
    case final(text: String, audioRange: ClosedRange<TimeInterval>)
    case failed(String)
}

protocol SpeechRecognitionEngine: Sendable {
    func prepare(locale: Locale) async throws -> AVAudioFormat
    func start() async throws -> AsyncThrowingStream<SpeechRecognitionEvent, any Error>
    func consume(_ buffer: CapturedAudioBuffer) async
    func finish() async throws
    func cancel() async
}

@MainActor
protocol AudioCaptureService: AnyObject {
    func start(format: AVAudioFormat) async throws -> AsyncStream<AudioCaptureEvent>
    func pause() throws
    func resume() throws
    func stop()
}

protocol FeedbackEngine: Sendable {
    func realtimeFeedback(for request: RealtimeFeedbackRequest) async throws -> RealtimeFeedback
    func report(for request: DeepReportRequest) async throws
        -> AsyncThrowingStream<ReportStreamEvent, any Error>
    func cancelRealtimeFeedback() async
    func cancelReport(sessionID: UUID) async
}

enum PermissionKind: String, CaseIterable, Sendable {
    case microphone
    case speechRecognition
}

enum PermissionState: String, Sendable {
    case notDetermined
    case granted
    case denied
}

@MainActor
protocol PermissionService: AnyObject {
    func status(for permission: PermissionKind) -> PermissionState
    func request(_ permission: PermissionKind) async -> PermissionState
    func openSystemSettings()
}

struct SharePayload: Equatable, Sendable {
    let title: String
    let text: String
    let markdownData: Data?
}

struct SessionExportSnapshot: Equatable, Sendable {
    let topic: String
    let goal: String
    let createdAt: Date
    let effectiveDuration: TimeInterval
    let effectiveTextUnits: Int
    let unitsPerMinute: Double?
    let issueCount: Int
    let nextFocus: String
    let transcript: String
    let reportSummary: String?
}

protocol ShareService: Sendable {
    func payload(for session: SessionExportSnapshot, includeReport: Bool, includeTranscript: Bool) -> SharePayload
}

protocol StorageUsageService: Sendable {
    func localStorageBytes() async -> Int64
}

protocol AppLogger: Sendable {
    func info(_ message: String)
    func error(_ message: String)
}

struct AppFeatureFlags: Equatable, Sendable {
    var realtimeAIAvailable: Bool
    var reportAIAvailable: Bool

    static let production = AppFeatureFlags(
        realtimeAIAvailable: true,
        reportAIAvailable: true
    )
}

enum ServiceError: LocalizedError, Equatable {
    case unavailable(String)
    case unsupportedLocale
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): message
        case .unsupportedLocale: "当前设备暂不支持普通话语音识别。"
        case .invalidConfiguration: "服务配置缺失，请稍后重试。"
        }
    }
}
