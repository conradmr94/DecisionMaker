import Foundation
import SwiftData

@Model
final class DecisionSet {
    @Attribute(.unique) var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade) var choices: [Choice]
    var lastPicked: String?

    init(name: String, choices: [Choice] = []) {
        self.id = UUID()
        self.name = name
        self.choices = choices
        self.lastPicked = nil
    }
}

