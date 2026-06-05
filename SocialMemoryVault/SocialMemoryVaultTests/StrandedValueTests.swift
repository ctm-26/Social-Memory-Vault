import XCTest
import SwiftData
@testable import SocialMemoryVault

@MainActor
final class StrandedValueTests: XCTestCase {

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

    // MARK: - 1. Scan finds stranded claims and produces a strong match

    func testScanFindsStrandedClaims() throws {
        // Insert the target entity
        let njhw = Entity(entityType: .organization, canonicalName: "NJHW")
        context.insert(njhw)

        // Insert a subject entity for the claim
        let subject = Entity(entityType: .person, canonicalName: "Jane Doe")
        context.insert(subject)
        try context.save()

        // Insert a stranded claim: objectEntityId is nil, value references "NJHW"
        let claim = Claim(
            subjectEntityId: subject.id,
            predicate: "works_at",
            objectEntityId: nil,
            value: "NJHW"
        )
        context.insert(claim)
        try context.save()

        let results = StrandedValueService.scan(context: context)

        XCTAssertEqual(results.count, 1)

        let scanResult = results[0]
        XCTAssertEqual(scanResult.claim.id, claim.id)

        if case .strong(let matchedEntity) = scanResult.matchKind {
            XCTAssertEqual(matchedEntity.id, njhw.id)
        } else {
            XCTFail("Expected .strong match, got \(scanResult.matchKind)")
        }
    }

    // MARK: - 2. Promote updates claim's objectEntityId and clears value

    func testPromoteUpdatesClaimCorrectly() throws {
        let njhw = Entity(entityType: .organization, canonicalName: "NJHW")
        context.insert(njhw)

        let subject = Entity(entityType: .person, canonicalName: "Jane Doe")
        context.insert(subject)
        try context.save()

        let claim = Claim(
            subjectEntityId: subject.id,
            predicate: "works_at",
            objectEntityId: nil,
            value: "NJHW"
        )
        context.insert(claim)
        try context.save()

        StrandedValueService.promote(claim: claim, to: njhw, context: context)

        XCTAssertEqual(claim.objectEntityId, njhw.id)
        XCTAssertNil(claim.value)
    }

    // MARK: - 3. Rescan after promote returns empty results

    func testRescanAfterPromoteReturnsEmpty() throws {
        let njhw = Entity(entityType: .organization, canonicalName: "NJHW")
        context.insert(njhw)

        let subject = Entity(entityType: .person, canonicalName: "Jane Doe")
        context.insert(subject)
        try context.save()

        let claim = Claim(
            subjectEntityId: subject.id,
            predicate: "works_at",
            objectEntityId: nil,
            value: "NJHW"
        )
        context.insert(claim)
        try context.save()

        StrandedValueService.promote(claim: claim, to: njhw, context: context)

        let results = StrandedValueService.scan(context: context)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - 4. Levenshtein distance of identical strings is 0

    func testLevenshteinExactMatch() {
        let distance = StrandedValueService.levenshtein("njhw", "njhw")
        XCTAssertEqual(distance, 0)
    }

    // MARK: - 5. Levenshtein distance with one deletion is 1

    func testLevenshteinOneEdit() {
        let distance = StrandedValueService.levenshtein("njhw", "njh")
        XCTAssertEqual(distance, 1)
    }

    // MARK: - 6. Levenshtein distance with multiple edits exceeds 2

    func testLevenshteinTwoEdits() {
        let distance = StrandedValueService.levenshtein("apple", "apricot")
        XCTAssertTrue(distance > 2, "Expected distance > 2 for 'apple' vs 'apricot', got \(distance)")
    }

    // MARK: - 7. Soft match detected when value differs by 1 character

    func testSoftMatchDetected() throws {
        let njhw = Entity(entityType: .organization, canonicalName: "NJHW")
        context.insert(njhw)

        let subject = Entity(entityType: .person, canonicalName: "Jane Doe")
        context.insert(subject)
        try context.save()

        // "NJHX" has Levenshtein distance 1 from "NJHW"
        let claim = Claim(
            subjectEntityId: subject.id,
            predicate: "works_at",
            objectEntityId: nil,
            value: "NJHX"
        )
        context.insert(claim)
        try context.save()

        let results = StrandedValueService.scan(context: context)
        XCTAssertEqual(results.count, 1)

        let scanResult = results[0]
        if case .soft(let matchedEntity, let distance) = scanResult.matchKind {
            XCTAssertEqual(matchedEntity.id, njhw.id)
            XCTAssertEqual(distance, 1)
        } else {
            XCTFail("Expected .soft match, got \(scanResult.matchKind)")
        }
    }
}

// MARK: - Test container helper

@MainActor
private func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([Entity.self, EntityAlias.self, Memory.self, MemoryEntityLink.self, Claim.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
