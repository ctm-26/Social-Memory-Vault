import XCTest
import SwiftData
@testable import SocialMemoryVault

@MainActor
final class EntityResolutionTests: XCTestCase {

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

    // MARK: - 1. Exact canonical name match (case-insensitive)

    func testExactCanonicalNameMatch() throws {
        let entity = Entity(entityType: .person, canonicalName: "Alex Smith")
        context.insert(entity)
        try context.save()

        let result = EntityResolutionService.findExactMatch(for: "alex smith", in: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.canonicalName, "Alex Smith")
    }

    // MARK: - 2. Case-insensitive alias match

    func testCaseInsensitiveAliasMatch() throws {
        let bob = Entity(entityType: .person, canonicalName: "Bob")
        context.insert(bob)
        try context.save()

        let alias = EntityAlias(entityId: bob.id, alias: "Bobby")
        context.insert(alias)
        try context.save()

        let result = EntityResolutionService.findExactMatch(for: "BOBBY", in: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.canonicalName, "Bob")
    }

    // MARK: - 3. Prefix match via findMatches

    func testPrefixMatchViaFindMatches() throws {
        let entity = Entity(entityType: .person, canonicalName: "Alexander")
        context.insert(entity)
        try context.save()

        let results = EntityResolutionService.findMatches(for: "Alex", in: context)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains(where: { $0.canonicalName == "Alexander" }))
    }

    // MARK: - 4. Empty input returns empty array

    func testEmptyInputReturnsEmpty() throws {
        let entity = Entity(entityType: .person, canonicalName: "Someone")
        context.insert(entity)
        try context.save()

        let results = EntityResolutionService.findMatches(for: "", in: context)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - 5. Single character returns nil from findExactMatch

    func testSingleCharReturnsNilExact() throws {
        let entity = Entity(entityType: .person, canonicalName: "Alice")
        context.insert(entity)
        try context.save()

        let result = EntityResolutionService.findExactMatch(for: "A", in: context)
        XCTAssertNil(result)
    }

    // MARK: - 6. No match on empty database returns nil

    func testNoMatchReturnsNil() throws {
        let result = EntityResolutionService.findExactMatch(for: "Zzzz", in: context)
        XCTAssertNil(result)
    }

    // MARK: - 7. Find entity by ID

    func testFindEntityById() throws {
        let knownId = "TEST-ID-1234"
        let entity = Entity(id: knownId, entityType: .person, canonicalName: "Unique Person")
        context.insert(entity)
        try context.save()

        let result = EntityResolutionService.findEntity(byId: knownId, in: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, knownId)
        XCTAssertEqual(result?.canonicalName, "Unique Person")
    }

    // MARK: - 8. Find alias returns entity-alias pair

    func testFindAlias() throws {
        let entity = Entity(entityType: .person, canonicalName: "Alexander Hamilton")
        context.insert(entity)
        try context.save()

        let alias = EntityAlias(entityId: entity.id, alias: "Al")
        context.insert(alias)
        try context.save()

        let results = EntityResolutionService.findAlias(containing: "Al", in: context)
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.entity.canonicalName, "Alexander Hamilton")
        XCTAssertEqual(results.first?.alias.alias, "Al")
    }
}

// MARK: - Test container helper

@MainActor
private func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([Entity.self, EntityAlias.self, Memory.self, MemoryEntityLink.self, Claim.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
