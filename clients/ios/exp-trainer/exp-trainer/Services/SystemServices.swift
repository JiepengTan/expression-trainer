import AVFAudio
import CoreTransferable
import Foundation
import OSLog
import Speech
import UIKit
import UniformTypeIdentifiers

@MainActor
final class SystemPermissionService: PermissionService {
    func status(for permission: PermissionKind) -> PermissionState {
        switch permission {
        case .microphone:
            switch AVAudioApplication.shared.recordPermission {
            case .granted: .granted
            case .denied: .denied
            case .undetermined: .notDetermined
            @unknown default: .notDetermined
            }
        case .speechRecognition:
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: .granted
            case .denied, .restricted: .denied
            case .notDetermined: .notDetermined
            @unknown default: .notDetermined
            }
        }
    }

    func request(_ permission: PermissionKind) async -> PermissionState {
        switch permission {
        case .microphone:
            let granted = await AVAudioApplication.requestRecordPermission()
            return granted ? .granted : .denied
        case .speechRecognition:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            return status == .authorized ? .granted : .denied
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct DefaultShareService: ShareService {
    func payload(
        for session: SessionExportSnapshot,
        includeReport: Bool,
        includeTranscript: Bool
    ) -> SharePayload {
        let date = session.createdAt.formatted(date: .abbreviated, time: .shortened)
        let rate = session.unitsPerMinute.map { String(format: "%.0f", $0) } ?? "—"
        var sections = [
            "# Expression Trainer 训练记录",
            "",
            "- 主题：\(session.topic.isEmpty ? "自由表达" : session.topic)",
            "- 目标：\(session.goal)",
            "- 时间：\(date)",
            "- 有效时长：\(Int(session.effectiveDuration)) 秒",
            "- 有效字数：\(session.effectiveTextUnits)",
            "- 语速：\(rate) 字/分钟",
            "- 问题次数：\(session.issueCount)",
            "- 下次重点：\(session.nextFocus)"
        ]
        if includeReport, let summary = session.reportSummary, !summary.isEmpty {
            sections += ["", "## 复盘", "", summary]
        }
        if includeTranscript {
            sections += ["", "## 逐字稿", "", session.transcript]
        }
        let markdown = sections.joined(separator: "\n")
        return SharePayload(
            title: session.topic.isEmpty ? "训练记录" : session.topic,
            text: markdown,
            markdownData: markdown.data(using: .utf8)
        )
    }
}

struct MarkdownExportDocument: Transferable, Sendable {
    let filename: String
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(
            exportedContentType: UTType(filenameExtension: "md") ?? .plainText
        ) { document in
            let safeName = document.filename
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let url = FileManager.default.temporaryDirectory
                .appending(path: safeName)
                .appendingPathExtension("md")
            try document.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct ApplicationSupportStorageUsageService: StorageUsageService {
    func localStorageBytes() async -> Int64 {
        Self.calculateLocalStorageBytes()
    }

    private static func calculateLocalStorageBytes() -> Int64 {
        guard let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return 0 }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys)
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

struct PrivacyAppLogger: AppLogger {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ExpressionTrainer",
        category: "app"
    )

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

actor DisabledFeedbackEngine: FeedbackEngine {
    func realtimeFeedback(for request: RealtimeFeedbackRequest) async throws -> RealtimeFeedback {
        throw ServiceError.unavailable("AI 服务当前不可用，本地训练不受影响。")
    }

    func report(for request: DeepReportRequest) async throws
        -> AsyncThrowingStream<ReportStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ServiceError.unavailable("深度报告服务尚未配置。"))
        }
    }

    func cancelRealtimeFeedback() async {}
    func cancelReport(sessionID: UUID) async {}
}
