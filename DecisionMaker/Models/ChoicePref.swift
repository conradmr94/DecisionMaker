import Foundation
import SwiftData

@Model
final class ChoicePref {
    @Attribute(.unique) var id: UUID
    var title: String
    var success: Int
    var failure: Int
    var lastUsed: Date?

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.success = 0
        self.failure = 0
        self.lastUsed = nil
    }
}
