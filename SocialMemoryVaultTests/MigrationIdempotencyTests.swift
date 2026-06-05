import XCTest
import SwiftData
@testable import SocialMemoryVault

@MainActor
final class MigrationIdempotencyTests: XCTestCase {

    // Reference IDs that match MigrationService's hardcoded values
    private let christinaId   = "717F2264-47A7-426E-91E4-E22DFB80D3ED"
    private let njhwId        = "627A02A6-E8FC-421E-8CB2-A1544BE7C714"
    private let addressId     = "BC9CB4EC-8108-4B3A-AA14-BDC5657E062A"
    private let memoryId      = "509A0843-BFB0-47A3-8D6A-05AD0D642B3B"
    private let brokenClaimId = "B3FD3489-9E0F-4532-8F7F-A8A5B78F03B6"
    private let linkId        = "EB55DB63-4E13-4C04-85FB-4CF5F4E061D8"

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeTestContainer()
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - Seed helper

    private func seedMigrationData() throws {
        // Entity: Christina Romeo (person)
        let christina = Entity(
            id: christinaId,
            entityType: .person,
            canonicalName: "Christina Romeo",
            notes: "Therapist at NJHW"
        )
        context.insert(christina)

        // Entity: NJHW (organization)
        let njhw = Entity(
            id: njhwId,
            entityType: .organization,
            canonicalName: "NJHW",
            notes: "North Jersey Health & Wellness"
        )
        context.insert(njhw)

        // Entity: Address (place)
        let address = Entity(
            id: addressId,
            entityType: .place,
            canonicalName: "35 N Spruce St Ramsey, NJ"
        )
        context.insert(address)

        // Memory
        let memory = SocialMemoryVault.Memory(
            id: memoryId,
            body: "Talked about psychologytoday.com"
        )
        context.insert(memory)

        // Broken claim: works_at with value "NJHW" but no objectEntityId or memoryId
        let brokenClaim = Claim(
            id: brokenClaimId,
            subjectEntityId: christinaId,
            predicate: "works_at",
            objectEntityId: nil,
            value: "NJHW",
            memoryId: nil
        )
        context.insert(brokenClaim)

        // MemoryEntityLink: Christina as participant in the memory
        let link = MemoryEntityLink(
            id: linkId,
            memoryId: memoryId,
            entityId: christinaId,
            role: .participant
        )
        context.insert(link)

        try context.save()
    }

    // MARK: - Fetch helpers

    private func fetchAllClaims() throws -> [Claim] {
        let descriptor = FetchDescriptor<Claim>()
        return try context.fetch(descriptor)
    }

    private func fetchAllAliases() throws -> [EntityAlias] {
        let descriptor = FetchDescriptor<EntityAlias>()
        return try context.fetch(descriptor)
    }

    private func fetchAllLinks() throws -> [MemoryEntityLink] {
        let descriptor = FetchDescriptor<MemoryEntityLink>()
        return try context.fetch(descriptor)
    }

    private func fetchClaim(id: String) throws -> Claim? {
        var descriptor = FetchDescriptor<Claim>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchEntity(id: String) throws -> Entity? {
        var descriptor = FetchDescriptor<Entity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - 1. Migration applies all 8 changes correctly

    func testMigrationAppliesCorrectly() throws {
        try seedMigrationData()

        MigrationService.applyDataCorrectionV1(context: context)
        try context.save()

        // 1a. Broken claim is fixed: objectEntityId == njhwId, value == nil, memoryId == memoryId
        let brokenClaim = try XCTUnwrap(fetchClaim(id: brokenClaimId),
                                        "brokenClaim should still exist after migration")
        XCTAssertEqual(brokenClaim.objectEntityId, njhwId,
                       "brokenClaim.objectEntityId should be njhwId")
        XCTAssertNil(brokenClaim.value,
                     "brokenClaim.value should be nil after promotion")
        XCTAssertEqual(brokenClaim.memoryId, memoryId,
                       "brokenClaim.memoryId should be set to memoryId")

        // 1b. Total of 4 claims: brokenClaim + has_role + located_at + recommended_resource
        let allClaims = try fetchAllClaims()
        XCTAssertEqual(allClaims.count, 4, "Expected 4 claims total after migration")

        // 1c. Exactly 1 alias: "North Jersey Health & Wellness" for NJHW
        let allAliases = try fetchAllAliases()
        XCTAssertEqual(allAliases.count, 1, "Expected exactly 1 alias after migration")
        XCTAssertEqual(allAliases.first?.alias, "North Jersey Health & Wellness")

        // 1d. Exactly 2 MemoryEntityLinks: original participant link + new address location link
        let allLinks = try fetchAllLinks()
        XCTAssertEqual(allLinks.count, 2, "Expected 2 MemoryEntityLinks after migration")

        // 1e. Christina's notes are cleared
        let christina = try XCTUnwrap(fetchEntity(id: christinaId))
        XCTAssertNil(christina.notes, "Christina's notes should be nil after migration")

        // 1f. NJHW's notes are cleared
        let njhw = try XCTUnwrap(fetchEntity(id: njhwId))
        XCTAssertNil(njhw.notes, "NJHW's notes should be nil after migration")
    }

    // MARK: - 2. Migration is idempotent (applying twice produces the same result)

    func testMigrationIsIdempotent() throws {
        try seedMigrationData()

        // Apply migration twice
        MigrationService.applyDataCorrectionV1(context: context)
        try context.save()
        MigrationService.applyDataCorrectionV1(context: context)
        try context.save()

        // Still exactly 4 claims — no duplicates
        let allClaims = try fetchAllClaims()
        XCTAssertEqual(allClaims.count, 4, "Expected exactly 4 claims after two migrations (no duplicates)")

        // Still exactly 1 alias
        let allAliases = try fetchAllAliases()
        XCTAssertEqual(allAliases.count, 1, "Expected exactly 1 alias after two migrations (no duplicates)")

        // Still exactly 2 MemoryEntityLinks
        let allLinks = try fetchAllLinks()
        XCTAssertEqual(allLinks.count, 2, "Expected exactly 2 MemoryEntityLinks after two migrations (no duplicates)")
    }

    // MARK: - 3. Migration on empty database does not crash and produces no records

    func testMigrationOnEmptyDatabase() throws {
        // Do NOT seed anything — empty container

        // Should not throw or crash
        MigrationService.applyDataCorrectionV1(context: context)
        try context.save()

        let allClaims = try fetchAllClaims()
        XCTAssertEqual(allClaims.count, 0, "Expected 0 claims on empty database")

        let allAliases = try fetchAllAliases()
        XCTAssertEqual(allAliases.count, 0, "Expected 0 aliases on empty database")

        let allLinks = try fetchAllLinks()
        XCTAssertEqual(allLinks.count, 0, "Expected 0 MemoryEntityLinks on empty database")
    }
}

// MARK: - Test container helper

@MainActor
private func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([Entity.self, EntityAlias.self, Memory.self, MemoryEntityLink.self, Claim.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
