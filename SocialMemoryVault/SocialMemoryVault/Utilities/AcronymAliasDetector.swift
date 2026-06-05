import Foundation

struct AcronymAliasDetector {

    // MARK: - Acronym check

    /// Returns `notes` as a suggested alias when the initials of its letter-starting
    /// words spell out `canonicalName` (case-insensitive).
    ///
    /// Guards:
    ///   - `canonicalName` must be 2–6 characters, all uppercase ASCII letters only
    ///     (no digits, no spaces, no punctuation).
    ///   - The phrase in `notes` must produce matching initials.
    ///
    /// Example: ("NJHW", "North Jersey Health & Wellness") → "North Jersey Health & Wellness"
    ///   Words: ["North", "Jersey", "Health", "&", "Wellness"]
    ///   Letter-starting words: ["North", "Jersey", "Health", "Wellness"]
    ///   Initials: "NJHW" == "NJHW" ✓
    static func checkAcronymAlias(canonicalName: String, notes: String) -> String? {
        // Validate canonicalName: 2–6 uppercase ASCII letters only
        let nameChars = Array(canonicalName)
        guard nameChars.count >= 2, nameChars.count <= 6 else { return nil }
        guard nameChars.allSatisfy({ $0.isLetter && $0.isUppercase && $0.isASCII }) else { return nil }

        // Split notes on whitespace, filter to words whose first character is a letter
        let words = notes.split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { $0.first?.isLetter == true }

        guard !words.isEmpty else { return nil }

        // Build initials string from letter-starting words
        let initials = words.compactMap { $0.first.map { String($0).uppercased() } }.joined()

        guard initials.caseInsensitiveCompare(canonicalName) == .orderedSame else { return nil }

        return notes
    }

    // MARK: - Short proper noun check

    /// Returns `true` when `notes` looks like a proper-noun phrase suitable for use
    /// as a display alias:
    ///   - At most 50 characters total.
    ///   - Contains none of `,`, `;`, `.`.
    ///   - Every word (split on whitespace) starts with an uppercase letter.
    ///   - At least one word present.
    ///
    /// Examples:
    ///   "North Jersey Health Wellness"  → true
    ///   "Therapy office in Ramsey"      → false  ("office", "in" are not Title-Case)
    static func checkShortProperNoun(notes: String) -> Bool {
        guard notes.count <= 50 else { return false }
        guard !notes.contains(","), !notes.contains(";"), !notes.contains(".") else { return false }

        let words = notes.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return false }

        return words.allSatisfy { word in
            guard let first = word.first else { return false }
            return first.isUppercase
        }
    }
}
