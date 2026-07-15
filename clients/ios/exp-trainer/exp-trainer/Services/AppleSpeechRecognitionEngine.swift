import AVFAudio
import CoreMedia
import Foundation
import Speech

actor AppleSpeechRecognitionEngine: SpeechRecognitionEngine {
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    func prepare(locale requestedLocale: Locale) async throws -> AVAudioFormat {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw ServiceError.unsupportedLocale
        }
        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .timeIndexedProgressiveTranscription
        )
        let modules: [any SpeechModule] = [transcriber]
        switch await AssetInventory.status(forModules: modules) {
        case .unsupported:
            throw ServiceError.unsupportedLocale
        case .supported, .downloading:
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                try await request.downloadAndInstall()
            }
        case .installed:
            break
        @unknown default:
            throw ServiceError.unavailable("无法确认语音资源状态。")
        }
        _ = try await AssetInventory.reserve(locale: locale)

        let analyzer = SpeechAnalyzer(modules: modules)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
            throw ServiceError.unavailable("无法准备语音识别音频格式。")
        }
        try await analyzer.prepareToAnalyze(in: format)
        self.transcriber = transcriber
        self.analyzer = analyzer
        return format
    }

    func start() async throws -> AsyncThrowingStream<SpeechRecognitionEvent, any Error> {
        guard let analyzer, let transcriber else {
            throw ServiceError.unavailable("语音资源尚未准备完成。")
        }
        let input = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = input.continuation
        try await analyzer.start(inputSequence: input.stream)

        return AsyncThrowingStream { continuation in
            continuation.yield(.ready)
            resultsTask = Task {
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { continue }
                        let start = max(0, result.range.start.seconds)
                        let end = max(start, result.range.end.seconds)
                        if result.isFinal {
                            continuation.yield(.final(text: text, audioRange: start...end))
                        } else {
                            continuation.yield(.partial(text: text, audioRange: start...end))
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.stopResultDelivery() }
            }
        }
    }

    func consume(_ buffer: CapturedAudioBuffer) {
        inputContinuation?.yield(
            AnalyzerInput(
                buffer: buffer.buffer,
                bufferStartTime: CMTime(seconds: buffer.timestamp, preferredTimescale: 1_000)
            )
        )
    }

    func finish() async throws {
        inputContinuation?.finish()
        inputContinuation = nil
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
    }

    func cancel() async {
        inputContinuation?.finish()
        inputContinuation = nil
        await analyzer?.cancelAndFinishNow()
        stopResultDelivery()
    }

    private func stopResultDelivery() {
        resultsTask?.cancel()
        resultsTask = nil
    }
}
