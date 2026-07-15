import AVFAudio
import Foundation

@MainActor
final class AppleAudioCaptureService: AudioCaptureService {
    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<AudioCaptureEvent>.Continuation?
    private var notificationTokens: [NSObjectProtocol] = []
    private var tapInstalled = false

    func start(format: AVAudioFormat) async throws -> AsyncStream<AudioCaptureEvent> {
        stop()
        let stream = AsyncStream<AudioCaptureEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(24)
        )
        continuation = stream.continuation

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
        try session.setActive(true)

        let inputNode = engine.inputNode
        let continuation = stream.continuation
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, time in
            guard let copy = Self.copy(buffer) else { return }
            let timestamp = time.sampleRate > 0
                ? Double(time.sampleTime) / time.sampleRate
                : 0
            continuation.yield(.buffer(CapturedAudioBuffer(buffer: copy, timestamp: timestamp)))
        }
        tapInstalled = true
        installNotificationObservers()
        engine.prepare()
        try engine.start()
        return stream.stream
    }

    func pause() throws {
        engine.pause()
    }

    func resume() throws {
        guard tapInstalled else { throw ServiceError.unavailable("录音尚未开始。") }
        try engine.start()
    }

    func stop() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        continuation?.finish()
        continuation = nil
        for token in notificationTokens { NotificationCenter.default.removeObserver(token) }
        notificationTokens.removeAll()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func installNotificationObservers() {
        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let type = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
                let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let canResume = type == .ended && AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
                Task { @MainActor [weak self] in self?.continuation?.yield(.interrupted(canResume: canResume)) }
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.continuation?.yield(.routeChanged) }
            }
        )
    }

    nonisolated private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let destination = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: source.frameCapacity
        ) else { return nil }
        destination.frameLength = source.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
        for index in 0..<min(sourceBuffers.count, destinationBuffers.count) {
            guard let sourceData = sourceBuffers[index].mData,
                  let destinationData = destinationBuffers[index].mData else { continue }
            memcpy(
                destinationData,
                sourceData,
                min(sourceBuffers[index].mDataByteSize, destinationBuffers[index].mDataByteSize).toInt()
            )
        }
        return destination
    }
}

private extension UInt32 {
    func toInt() -> Int { Int(self) }
}
