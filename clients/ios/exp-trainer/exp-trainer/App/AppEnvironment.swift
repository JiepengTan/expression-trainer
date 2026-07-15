import Foundation
import SwiftData

@MainActor
struct AppEnvironment {
    let repository: any TrainingSessionRepository
    let speechRecognition: any SpeechRecognitionEngine
    let audioCapture: any AudioCaptureService
    let lexiconAnalyzer: any LexiconAnalyzing
    let feedback: any FeedbackEngine
    let permissions: any PermissionService
    let share: any ShareService
    let storage: any StorageUsageService
    let logger: any AppLogger
    let featureFlags: AppFeatureFlags

    static func live(modelContext: ModelContext) -> AppEnvironment {
        AppEnvironment(
            repository: SwiftDataTrainingSessionRepository(modelContext: modelContext),
            speechRecognition: AppleSpeechRecognitionEngine(),
            audioCapture: AppleAudioCaptureService(),
            lexiconAnalyzer: LexiconAnalyzer(),
            feedback: BackendFeedbackEngine.fromBundleConfiguration(),
            permissions: SystemPermissionService(),
            share: DefaultShareService(),
            storage: ApplicationSupportStorageUsageService(),
            logger: PrivacyAppLogger(),
            featureFlags: .production
        )
    }
}
