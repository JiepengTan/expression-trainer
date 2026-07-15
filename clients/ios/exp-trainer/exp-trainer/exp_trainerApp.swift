import SwiftData
import SwiftUI

@main
@MainActor
struct exp_trainerApp: App {
    let sharedModelContainer: ModelContainer
    @State private var appModel: AppModel

    init() {
        let schema = Schema(VersionedSchemaV1.models)
        let useInMemoryStore = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let diskConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: useInMemoryStore)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [diskConfiguration])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let memoryContainer = try? ModelContainer(for: schema, configurations: [fallback]) else {
                fatalError("Could not create ModelContainer: \(error)")
            }
            container = memoryContainer
        }
        sharedModelContainer = container
        let environment = AppEnvironment.live(modelContext: container.mainContext)
        _appModel = State(initialValue: AppModel(environment: environment))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
