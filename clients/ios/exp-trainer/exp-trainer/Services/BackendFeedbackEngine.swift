import CryptoKit
import DeviceCheck
import Foundation

actor BackendFeedbackEngine: FeedbackEngine {
    private let baseURL: URL
    private let session: URLSession
    private let appAttest: AppAttestClient
    private var accessToken: String?
    private var tokenExpiresAt: Date?
    private var realtimeTask: Task<RealtimeFeedback, any Error>?
    private var reportTasks: [UUID: Task<Void, Never>] = [:]

    init(
        baseURL: URL,
        session: URLSession = .shared,
        appAttest: AppAttestClient = AppAttestClient()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.appAttest = appAttest
    }

    nonisolated static func fromBundleConfiguration() -> any FeedbackEngine {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
              !raw.isEmpty,
              !raw.contains("$("),
              let url = URL(string: raw) else {
            return DisabledFeedbackEngine()
        }
        return BackendFeedbackEngine(baseURL: url)
    }

    func realtimeFeedback(for request: RealtimeFeedbackRequest) async throws -> RealtimeFeedback {
        realtimeTask?.cancel()
        let task = Task<RealtimeFeedback, any Error> {
            let token = try await validAccessToken()
            var urlRequest = URLRequest(url: baseURL.appending(path: "/v1/realtime-feedback"))
            urlRequest.httpMethod = "POST"
            urlRequest.timeoutInterval = 5
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            urlRequest.httpBody = try JSONEncoder.api.encode(request)
            let (data, response) = try await session.data(for: urlRequest)
            try Self.validate(response: response)
            let feedback = try JSONDecoder.api.decode(RealtimeFeedback.self, from: data)
            guard !feedback.message.isEmpty, feedback.message.count <= 24 else {
                throw BackendError.invalidResponse
            }
            return feedback
        }
        realtimeTask = task
        defer { realtimeTask = nil }
        return try await task.value
    }

    func report(for request: DeepReportRequest) async throws
        -> AsyncThrowingStream<ReportStreamEvent, any Error> {
        cancelReport(sessionID: request.sessionID)
        return AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish(throwing: CancellationError())
                    return
                }
                do {
                    try await streamReport(request, attempt: 0, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
                await removeReportTask(sessionID: request.sessionID)
            }
            reportTasks[request.sessionID] = task
            continuation.onTermination = { [weak self] _ in
                Task { await self?.cancelReport(sessionID: request.sessionID) }
            }
        }
    }

    func cancelRealtimeFeedback() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func cancelReport(sessionID: UUID) {
        reportTasks.removeValue(forKey: sessionID)?.cancel()
    }

    private func streamReport(
        _ request: DeepReportRequest,
        attempt: Int,
        continuation: AsyncThrowingStream<ReportStreamEvent, any Error>.Continuation
    ) async throws {
        let token = try await validAccessToken()
        var urlRequest = URLRequest(url: baseURL.appending(path: "/v1/reports"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder.api.encode(request)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        if let http = response as? HTTPURLResponse, (500...599).contains(http.statusCode), attempt == 0 {
            try await streamReport(request, attempt: 1, continuation: continuation)
            return
        }
        try Self.validate(response: response)
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard payload != "[DONE]", let data = payload.data(using: .utf8) else { continue }
            let event = try JSONDecoder.api.decode(SSEReportEnvelope.self, from: data)
            switch event.type {
            case "progress":
                continuation.yield(.progress(event.progress ?? 0, event.message ?? "正在生成"))
            case "partial":
                if let report = event.report { continuation.yield(.partial(report)) }
            case "completed":
                guard let report = event.report else { throw BackendError.invalidResponse }
                continuation.yield(.completed(report))
            case "failed":
                throw BackendError.server(event.message ?? "报告生成失败")
            default:
                continue
            }
        }
    }

    private func validAccessToken() async throws -> String {
        if let accessToken, let tokenExpiresAt, tokenExpiresAt > .now.addingTimeInterval(30) {
            return accessToken
        }
        let attestation = try await appAttest.makeAttestationEnvelope()
        var request = URLRequest(url: baseURL.appending(path: "/v1/anonymous/session"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.api.encode(attestation)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response)
        let token = try JSONDecoder.api.decode(AnonymousSessionResponse.self, from: data)
        await appAttest.markCurrentKeyAccepted()
        accessToken = token.accessToken
        tokenExpiresAt = token.expiresAt ?? .now.addingTimeInterval(20 * 60)
        return token.accessToken
    }

    private func removeReportTask(sessionID: UUID) {
        reportTasks[sessionID] = nil
    }

    private nonisolated static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BackendError.http(code)
        }
    }
}

actor AppAttestClient {
    private let service = DCAppAttestService.shared
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func makeAttestationEnvelope() async throws -> AppAttestEnvelope {
        guard service.isSupported else {
            return AppAttestEnvelope(
                platform: "ios",
                appAttestSupported: false,
                keyID: nil,
                clientDataHash: nil,
                attestation: nil,
                assertion: nil
            )
        }
        let clientData = UUID().uuidString.data(using: .utf8) ?? Data()
        let hash = Data(SHA256.hash(data: clientData))
        let keyID: String
        if let saved = defaults.string(forKey: Keys.keyID) {
            keyID = saved
        } else {
            keyID = try await service.generateKey()
            defaults.set(keyID, forKey: Keys.keyID)
        }

        if defaults.bool(forKey: Keys.keyAccepted) {
            let assertion = try await service.generateAssertion(keyID, clientDataHash: hash)
            return AppAttestEnvelope(
                platform: "ios",
                appAttestSupported: true,
                keyID: keyID,
                clientDataHash: hash.base64EncodedString(),
                attestation: nil,
                assertion: assertion.base64EncodedString()
            )
        }

        if let pending = defaults.data(forKey: Keys.pendingAttestation),
           let pendingHash = defaults.data(forKey: Keys.pendingClientDataHash) {
            return AppAttestEnvelope(
                platform: "ios",
                appAttestSupported: true,
                keyID: keyID,
                clientDataHash: pendingHash.base64EncodedString(),
                attestation: pending.base64EncodedString(),
                assertion: nil
            )
        }
        let attestation = try await service.attestKey(keyID, clientDataHash: hash)
        defaults.set(attestation, forKey: Keys.pendingAttestation)
        defaults.set(hash, forKey: Keys.pendingClientDataHash)
        return AppAttestEnvelope(
            platform: "ios",
            appAttestSupported: true,
            keyID: keyID,
            clientDataHash: hash.base64EncodedString(),
            attestation: attestation.base64EncodedString(),
            assertion: nil
        )
    }

    func markCurrentKeyAccepted() {
        guard service.isSupported else { return }
        defaults.set(true, forKey: Keys.keyAccepted)
        defaults.removeObject(forKey: Keys.pendingAttestation)
        defaults.removeObject(forKey: Keys.pendingClientDataHash)
    }

    private enum Keys {
        static let keyID = "appAttest.keyID"
        static let keyAccepted = "appAttest.keyAccepted"
        static let pendingAttestation = "appAttest.pendingAttestation"
        static let pendingClientDataHash = "appAttest.pendingClientDataHash"
    }
}

struct AppAttestEnvelope: Codable, Sendable {
    let platform: String
    let appAttestSupported: Bool
    let keyID: String?
    let clientDataHash: String?
    let attestation: String?
    let assertion: String?
}

private struct AnonymousSessionResponse: Codable {
    let accessToken: String
    let expiresAt: Date?
}

private struct SSEReportEnvelope: Codable {
    let type: String
    let progress: Double?
    let message: String?
    let report: AITrainingReport?
}

enum BackendError: LocalizedError {
    case http(Int)
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .http(let code): "服务请求失败（\(code)）"
        case .invalidResponse: "服务返回了无法识别的数据。"
        case .server(let message): message
        }
    }
}

private extension JSONEncoder {
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
