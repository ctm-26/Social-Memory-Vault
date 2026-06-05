import Foundation
import SwiftData

struct StrandedValueService {

    enum MatchKind {
        case strong(entity: Entity)
        case soft(entity: Entity, distance: Int)
        case none
    }

    struct ScanResult: Identifiable {
        let id: String  // claim.id
        let claim: Claim
        let matchKind: MatchKind
    }

    /// Scan for claims where objectEntityId is nil and value is non-nil.
    /// For each, attempt to match value against entities.
    static func scan(context: ModelContext) -> [ScanResult] {
        // Fetch stranded claims
        var claimDescriptor = FetchDescriptor<Claim>()
        let allClaims = (try? context.fetch(claimDescriptor)) ?? []
        let stranded = allClaims.filter { $0.objectEntityId == nil && $0.value != nil && !($0.value!.isEmpty) }

        // Fetch all entities and aliases for matching
        var entityDescriptor = FetchDescriptor<Entity>()
        let allEntities = (try? context.fetch(entityDescriptor)) ?? []

        var aliasDescriptor = FetchDescriptor<EntityAlias>()
        let allAliases = (try? context.fetch(aliasDescriptor)) ?? []

        return stranded.map { claim in
            let value = claim.value!
            let match = findMatch(value: value, entities: allEntities, aliases: allAliases)
            return ScanResult(id: claim.id, claim: claim, matchKind: match)
        }
    }

    /// Promote a stranded claim: set objectEntityId, clear value.
    static func promote(claim: Claim, to entity: Entity, context: ModelContext) {
        claim.objectEntityId = entity.id
        claim.value          = nil
        claim.updatedAt      = Date()
        try? context.save()
    }

    // MARK: - Private

    private static func findMatch(value: String, entities: [Entity], aliases: [EntityAlias]) -> MatchKind {
        let lower = value.lowercased()

        // Strong match: exact case-insensitive on canonical name
        if let entity = entities.first(where: { $0.canonicalName.lowercased() == lower }) {
            return .strong(entity: entity)
        }
        // Strong match: exact case-insensitive on alias
        for alias in aliases {
            if alias.alias.lowercased() == lower,
               let entity = entities.first(where: { $0.id == alias.entityId }) {
                return .strong(entity: entity)
            }
        }

        // Soft match: Levenshtein distance ≤ 2 on canonical name
        for entity in entities {
            let d = levenshtein(lower, entity.canonicalName.lowercased())
            if d <= 2 { return .soft(entity: entity, distance: d) }
        }
        // Soft match: Levenshtein distance ≤ 2 on alias
        for alias in aliases {
            let d = levenshtein(lower, alias.alias.lowercased())
            if d <= 2, let entity = entities.first(where: { $0.id == alias.entityId }) {
                return .soft(entity: entity, distance: d)
            }
        }

        return .none
    }

    // Standard Levenshtein distance
    static func levenshtein(_ s: String, _ t: String) -> Int {
        let s = Array(s), t = Array(t)
        let m = s.count, n = t.count
        if m == 0 { return n }
        if n == 0 { return m }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = s[i-1] == t[j-1] ? dp[i-1][j-1] : 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
            }
        }
        return dp[m][n]
    }
}
