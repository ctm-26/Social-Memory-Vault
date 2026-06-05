import XCTest
@testable import SocialMemoryVault

// No SwiftData needed — pure logic tests.
final class PredicateClassificationTests: XCTestCase {

    // MARK: - 1. All entity-typed predicates classify as .entity

    func testAllEntityPredicatesClassifyCorrectly() {
        for predicate in PredicateClassificationService.entityTypedPredicates {
            let result = PredicateClassificationService.classify(predicate)
            XCTAssertEqual(result, .entity, "Expected .entity for predicate '\(predicate)'")
        }
    }

    // MARK: - 2. All literal-typed predicates classify as .literal

    func testAllLiteralPredicatesClassifyCorrectly() {
        for predicate in PredicateClassificationService.literalTypedPredicates {
            let result = PredicateClassificationService.classify(predicate)
            XCTAssertEqual(result, .literal, "Expected .literal for predicate '\(predicate)'")
        }
    }

    // MARK: - 3. Free-form strings return .unknown

    func testFreeStringReturnsUnknown() {
        let unknownPredicates = ["ate_lunch_with", "favorite_color", "visited_together"]
        for predicate in unknownPredicates {
            let result = PredicateClassificationService.classify(predicate)
            XCTAssertEqual(result, .unknown, "Expected .unknown for predicate '\(predicate)'")
        }
    }

    // MARK: - 4. Empty string returns .unknown

    func testEmptyStringReturnsUnknown() {
        let result = PredicateClassificationService.classify("")
        XCTAssertEqual(result, .unknown)
    }

    // MARK: - 5. Case-insensitive entity classification

    func testCaseInsensitiveEntity() {
        let variants = ["Works_At", "WORKS_AT", "works_at"]
        for variant in variants {
            let result = PredicateClassificationService.classify(variant)
            XCTAssertEqual(result, .entity, "Expected .entity for variant '\(variant)'")
        }
    }

    // MARK: - 6. Case-insensitive literal classification

    func testCaseInsensitiveLiteral() {
        let variants = ["HAS_ROLE", "Has_Role"]
        for variant in variants {
            let result = PredicateClassificationService.classify(variant)
            XCTAssertEqual(result, .literal, "Expected .literal for variant '\(variant)'")
        }
    }

    // MARK: - 7. Leading/trailing whitespace is trimmed before classification

    func testWhitespaceTrimmed() {
        let result = PredicateClassificationService.classify("  works_at  ")
        XCTAssertEqual(result, .entity)
    }

    // MARK: - 8. Predicates from common suggestions list that are NOT in either typed set

    func testSampleUnknownPredicates() {
        // These appear in common suggestions but are NOT in entityTypedPredicates or literalTypedPredicates.
        let unknownPredicates = ["is_into", "interested_in", "uses_platform"]
        for predicate in unknownPredicates {
            let result = PredicateClassificationService.classify(predicate)
            XCTAssertEqual(result, .unknown, "Expected .unknown for predicate '\(predicate)'")
        }
    }
}

// MARK: - PredicateCategory Equatable conformance for tests

extension PredicateCategory: Equatable {
    public static func == (lhs: PredicateCategory, rhs: PredicateCategory) -> Bool {
        switch (lhs, rhs) {
        case (.entity, .entity): return true
        case (.literal, .literal): return true
        case (.unknown, .unknown): return true
        default: return false
        }
    }
}
