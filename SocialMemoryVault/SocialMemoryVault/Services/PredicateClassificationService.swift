import Foundation

enum PredicateCategory {
    case entity
    case literal
    case unknown
}

struct PredicateClassificationService {

    // TODO: v0.2 migrate to PredicateType.object_type column
    static let entityTypedPredicates: Set<String> = [
        "works_at", "lives_in", "owns", "knows", "friend_of",
        "sibling_of", "parent_of", "child_of", "married_to",
        "located_at", "part_of", "member_of", "manages",
        "reports_to", "founded", "attended"
    ]

    // TODO: v0.2 migrate to PredicateType.object_type column
    static let literalTypedPredicates: Set<String> = [
        "phone_number", "email", "birthday", "has_role",
        "has_address", "website", "url", "age", "height",
        "occupation_label", "recommended_resource"
    ]

    /// Case-insensitive, whitespace-normalized classification.
    static func classify(_ predicate: String) -> PredicateCategory {
        let normalized = predicate.trimmingCharacters(in: .whitespaces).lowercased()
        guard !normalized.isEmpty else { return .unknown }
        if entityTypedPredicates.contains(normalized) { return .entity }
        if literalTypedPredicates.contains(normalized) { return .literal }
        return .unknown
    }
}
