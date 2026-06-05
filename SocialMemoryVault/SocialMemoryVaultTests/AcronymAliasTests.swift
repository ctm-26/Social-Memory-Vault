import XCTest
@testable import SocialMemoryVault

// No SwiftData needed — pure logic tests.
final class AcronymAliasTests: XCTestCase {

    // MARK: - checkAcronymAlias

    // 1. NJHW matches "North Jersey Health & Wellness"
    func testNJHWMatch() {
        let result = AcronymAliasDetector.checkAcronymAlias(
            canonicalName: "NJHW",
            notes: "North Jersey Health & Wellness"
        )
        XCTAssertEqual(result, "North Jersey Health & Wellness")
    }

    // 2. IBM matches "International Business Machines"
    func testIBMMatch() {
        let result = AcronymAliasDetector.checkAcronymAlias(
            canonicalName: "IBM",
            notes: "International Business Machines"
        )
        XCTAssertEqual(result, "International Business Machines")
    }

    // 3. Mixed-case canonical name returns nil (not all-caps)
    func testNotAllCapsReturnNil() {
        let result = AcronymAliasDetector.checkAcronymAlias(
            canonicalName: "Apple",
            notes: "Cupertino company"
        )
        XCTAssertNil(result)
    }

    // 4. Initials of notes don't spell out the canonical name
    func testInitialsDontMatchReturnNil() {
        let result = AcronymAliasDetector.checkAcronymAlias(
            canonicalName: "NJHW",
            notes: "Therapy office in Ramsey"
        )
        XCTAssertNil(result)
    }

    // 5. Canonical name longer than 6 characters returns nil
    func testTooLongCanonicalReturnNil() {
        // "TOOLONG" is 7 characters — exceeds the 6-char maximum
        let result = AcronymAliasDetector.checkAcronymAlias(
            canonicalName: "TOOLONG",
            notes: "Test Of Order Looking On Nails Goats"
        )
        XCTAssertNil(result)
    }

    // 6. Canonical name shorter than 2 characters returns nil
    func testTooShortCanonicalReturnNil() {
        let result = AcronymAliasDetector.checkAcronymAlias(
            canonicalName: "A",
            notes: "Alpha"
        )
        XCTAssertNil(result)
    }

    // MARK: - checkShortProperNoun

    // 7. Title-case short string returns true
    func testTitleCaseShortStringTrue() {
        let result = AcronymAliasDetector.checkShortProperNoun(notes: "North Jersey Health Wellness")
        XCTAssertTrue(result)
    }

    // 8. Non-title-case string returns false
    func testNonTitleCaseFalse() {
        let result = AcronymAliasDetector.checkShortProperNoun(notes: "Therapy office in Ramsey")
        XCTAssertFalse(result)
    }

    // 9. String of 51 characters returns false (exceeds 50-char limit)
    func testTooLongFalse() {
        // Build a 51-character all-Title-Case string: "Aaaa Bbbb Cccc Dddd Eeee Ffff Gggg Hhhh Iiii Jjjj"
        // Count: 5*10 + 9 spaces = 59 chars — trim to exactly 51 Title-Case chars
        let fiftyOneChars = "Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota" // 50 chars
        XCTAssertEqual(fiftyOneChars.count, 50) // sanity check — expect true
        let overLimit = fiftyOneChars + "X"     // 51 chars
        XCTAssertEqual(overLimit.count, 51)
        let result = AcronymAliasDetector.checkShortProperNoun(notes: overLimit)
        XCTAssertFalse(result)
    }

    // 10. String containing a comma returns false
    func testContainsPunctuationFalse() {
        let result = AcronymAliasDetector.checkShortProperNoun(notes: "Jones, Bob")
        XCTAssertFalse(result)
    }

    // 11. Two-word title-case person name returns true
    func testTitleCasePersonName() {
        let result = AcronymAliasDetector.checkShortProperNoun(notes: "Christina Romeo")
        XCTAssertTrue(result)
    }

    // 12. Empty string returns false
    func testEmptyStringFalse() {
        let result = AcronymAliasDetector.checkShortProperNoun(notes: "")
        XCTAssertFalse(result)
    }
}
