import Foundation

struct AgeGroup: Identifiable, Hashable, Sendable {
    let minimumAge: Int
    let maximumAge: Int
    let title: String

    var id: String { databaseValue }
    var databaseValue: String { "\(minimumAge)–\(maximumAge)" }

    func overlaps(minimum: Int?, maximum: Int?) -> Bool {
        let lowerBound = minimum ?? Int.min
        let upperBound = maximum ?? Int.max
        return minimumAge <= upperBound && maximumAge >= lowerBound
    }

    static let supported: [AgeGroup] = [
        AgeGroup(minimumAge: 2, maximumAge: 5, title: "Early Childhood"),
        AgeGroup(minimumAge: 6, maximumAge: 8, title: "Elementary"),
        AgeGroup(minimumAge: 9, maximumAge: 12, title: "Preteen"),
        AgeGroup(minimumAge: 13, maximumAge: 15, title: "Teen"),
        AgeGroup(minimumAge: 16, maximumAge: 18, title: "High School"),
        AgeGroup(minimumAge: 18, maximumAge: 24, title: "Young Adult")
    ]

    static let child: [AgeGroup] = supported.filter { $0.minimumAge < 18 && $0.maximumAge <= 18 }
    static let independentlyManaged: [AgeGroup] = supported.filter { $0.minimumAge >= 18 }

    static func matching(_ databaseValue: String) -> AgeGroup? {
        let normalized = databaseValue.replacingOccurrences(of: "-", with: "–")
        if let supportedGroup = supported.first(where: { $0.databaseValue == normalized }) {
            return supportedGroup
        }

        let bounds = normalized.split(separator: "–").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard bounds.count == 2, bounds[0] <= bounds[1] else { return nil }
        return AgeGroup(minimumAge: bounds[0], maximumAge: bounds[1], title: "Age Group")
    }
}
