import Foundation
import SwiftData

struct MigrationService {

    private static let migrationKey = "migration_data_correction_v1"

    // MARK: - Public entry point

    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        applyDataCorrectionV1(context: context)
        try? context.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Migration body (internal so tests can call directly)

    static func applyDataCorrectionV1(context: ModelContext) {

        // Reference IDs
        let christinaId   = "717F2264-47A7-426E-91E4-E22DFB80D3ED"
        let njhwId        = "627A02A6-E8FC-421E-8CB2-A1544BE7C714"
        let addressId     = "BC9CB4EC-8108-4B3A-AA14-BDC5657E062A"
        let memoryId      = "509A0843-BFB0-47A3-8D6A-05AD0D642B3B"
        let brokenClaimId = "B3FD3489-9E0F-4532-8F7F-A8A5B78F03B6"

        // ---------------------------------------------------------------
        // 1. Fix broken Claim
        // ---------------------------------------------------------------
        var brokenDesc = FetchDescriptor<Claim>(
            predicate: #Predicate { $0.id == brokenClaimId }
        )
        brokenDesc.fetchLimit = 1
        if let broken = (try? context.fetch(brokenDesc))?.first {
            if broken.objectEntityId != njhwId || broken.value != nil || broken.memoryId != memoryId {
                broken.objectEntityId = njhwId
                broken.value          = nil
                broken.memoryId       = memoryId
                broken.updatedAt      = Date()
            }
        }

        // ---------------------------------------------------------------
        // 2. Add Claim — has_role "Therapist" (subject: christinaId)
        // ---------------------------------------------------------------
        let hasRolePred = "has_role"
        let therapistValue = "Therapist"
        var hasRoleDesc = FetchDescriptor<Claim>(
            predicate: #Predicate { $0.subjectEntityId == christinaId && $0.predicate == hasRolePred }
        )
        let existingHasRole = (try? context.fetch(hasRoleDesc)) ?? []
        if !existingHasRole.contains(where: { $0.value == therapistValue }) {
            let claim = Claim(
                subjectEntityId: christinaId,
                predicate: hasRolePred,
                value: therapistValue,
                memoryId: nil
            )
            context.insert(claim)
        }

        // ---------------------------------------------------------------
        // 3. Add Claim — located_at address (subject: njhwId)
        // ---------------------------------------------------------------
        let locatedAtPred = "located_at"
        var locatedAtDesc = FetchDescriptor<Claim>(
            predicate: #Predicate { $0.subjectEntityId == njhwId && $0.predicate == locatedAtPred }
        )
        let existingLocatedAt = (try? context.fetch(locatedAtDesc)) ?? []
        if !existingLocatedAt.contains(where: { $0.objectEntityId == addressId }) {
            let claim = Claim(
                subjectEntityId: njhwId,
                predicate: locatedAtPred,
                objectEntityId: addressId
            )
            context.insert(claim)
        }

        // ---------------------------------------------------------------
        // 4. Add Claim — recommended_resource "psychologytoday.com"
        // ---------------------------------------------------------------
        let recResourcePred  = "recommended_resource"
        let psychTodayValue  = "psychologytoday.com"
        var recResourceDesc  = FetchDescriptor<Claim>(
            predicate: #Predicate { $0.subjectEntityId == christinaId && $0.predicate == recResourcePred }
        )
        let existingRecResource = (try? context.fetch(recResourceDesc)) ?? []
        if !existingRecResource.contains(where: { $0.value == psychTodayValue }) {
            let claim = Claim(
                subjectEntityId: christinaId,
                predicate: recResourcePred,
                value: psychTodayValue,
                memoryId: memoryId
            )
            context.insert(claim)
        }

        // ---------------------------------------------------------------
        // 5. Add EntityAlias "North Jersey Health & Wellness" for NJHW
        // ---------------------------------------------------------------
        let njhwAliasText = "North Jersey Health & Wellness"
        var aliasDesc = FetchDescriptor<EntityAlias>(
            predicate: #Predicate { $0.entityId == njhwId }
        )
        let existingAliases = (try? context.fetch(aliasDesc)) ?? []
        let aliasAlreadyExists = existingAliases.contains(where: {
            $0.alias.caseInsensitiveCompare(njhwAliasText) == .orderedSame
        })
        if !aliasAlreadyExists {
            let alias = EntityAlias(entityId: njhwId, alias: njhwAliasText)
            context.insert(alias)
        }

        // ---------------------------------------------------------------
        // 6. Clear notes on Christina
        // ---------------------------------------------------------------
        var christinaDesc = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.id == christinaId }
        )
        christinaDesc.fetchLimit = 1
        if let christina = (try? context.fetch(christinaDesc))?.first {
            if christina.notes != nil {
                christina.notes     = nil
                christina.updatedAt = Date()
            }
        }

        // ---------------------------------------------------------------
        // 7. Clear notes on NJHW
        // ---------------------------------------------------------------
        var njhwDesc = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.id == njhwId }
        )
        njhwDesc.fetchLimit = 1
        if let njhw = (try? context.fetch(njhwDesc))?.first {
            if njhw.notes != nil {
                njhw.notes     = nil
                njhw.updatedAt = Date()
            }
        }

        // ---------------------------------------------------------------
        // 8. Add MemoryEntityLink — address as .location
        // ---------------------------------------------------------------
        let locationRoleRaw = LinkRole.location.rawValue
        var linkDesc = FetchDescriptor<MemoryEntityLink>(
            predicate: #Predicate { $0.memoryId == memoryId && $0.entityId == addressId }
        )
        let existingLinks = (try? context.fetch(linkDesc)) ?? []
        if !existingLinks.contains(where: { $0.role == locationRoleRaw }) {
            let link = MemoryEntityLink(
                memoryId: memoryId,
                entityId: addressId,
                role: .location
            )
            context.insert(link)
        }
    }
}
