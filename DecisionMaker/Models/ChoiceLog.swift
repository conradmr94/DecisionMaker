import Foundation
import SwiftData

@Model
final class ChoiceLog {
    @Attribute(.unique) var id: UUID
    var title: String
    var decidedAt: Date
    // Light context for future smarts
    var hourOfDay: Int
    var weekday: Int  // 1=Sun ... 7=Sat

    init(title: String, date: Date = Date(), calendar: Calendar = .current) {
        self.id = UUID()
        self.title = title
        self.decidedAt = date
        self.hourOfDay = calendar.component(.hour, from: date)
        self.weekday = calendar.component(.weekday, from: date)
    }
}
