import SwiftUI
import SwiftData

@main
struct SocialMemoryVaultApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([
            Entity.self, EntityAlias.self, Memory.self,
            MemoryEntityLink.self, Claim.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        // Run one-time data correction migration
        let migrationContext = ModelContext(container)
        MigrationService.runIfNeeded(context: migrationContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
