import Foundation
import SwiftData

struct EntityResolutionService {

    // MARK: - Find entities whose canonicalName contains the given text (case-insensitive)
    static func findMatches(for text: String, in context: ModelContext) -> [Entity] {
        guard !text.isEmpty else { return [] }
        var descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.canonicalName.localizedStandardContains(text) }
        )
        descriptor.sortBy = [SortDescriptor(\.canonicalName)]
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Find a single entity by its stable ID
    static func findEntity(byId id: String, in context: ModelContext) -> Entity? {
        var descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Find aliases whose text matches, paired with their parent Entity
    static func findAlias(
        containing text: String,
        in context: ModelContext
    ) -> [(entity: Entity, alias: EntityAlias)] {
        guard !text.isEmpty else { return [] }

        var aliasDescriptor = FetchDescriptor<EntityAlias>(
            predicate: #Predicate { $0.alias.localizedStandardContains(text) }
        )
        aliasDescriptor.sortBy = [SortDescriptor(\.alias)]

        let matchingAliases = (try? context.fetch(aliasDescriptor)) ?? []

        // Resolve each alias to its parent Entity; drop orphans
        return matchingAliases.compactMap { aliasObj -> (entity: Entity, alias: EntityAlias)? in
            guard let entity = findEntity(byId: aliasObj.entityId, in: context) else {
                return nil
            }
            return (entity: entity, alias: aliasObj)
        }
    }

    // MARK: - Find first entity with exact case-insensitive match on canonicalName or any alias

    /// Find the first entity with an EXACT case-insensitive match on canonicalName or any alias.
    /// Returns nil if input is fewer than 2 characters or no exact match found.
    static func findExactMatch(for text: String, in context: ModelContext) -> Entity? {
        guard text.count >= 2 else { return nil }

        // Check canonical name (exact, case-insensitive) — use contains then filter
        let nameMatches = findMatches(for: text, in: context)
        if let entity = nameMatches.first(where: { $0.canonicalName.caseInsensitiveCompare(text) == .orderedSame }) {
            return entity
        }

        // Check aliases (exact, case-insensitive)
        let aliasPairs = findAlias(containing: text, in: context)
        return aliasPairs.first(where: { $0.alias.alias.caseInsensitiveCompare(text) == .orderedSame })?.entity
    }
}
