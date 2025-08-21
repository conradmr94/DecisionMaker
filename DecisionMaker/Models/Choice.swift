import Foundation
import SwiftData

@Model
final class Choice {
    @Attribute(.unique) var id: UUID
    var title: String

    init(title: String) {
        self.id = UUID()
        self.title = title
    }
}

