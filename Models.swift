import Foundation
import SwiftData
import SwiftUI

// MARK: - Модели

@Model
final class SpendCategory {
    @Attribute(.unique) var name: String
    var emoji: String
    var colorHex: String
    var sortOrder: Int

    init(name: String, emoji: String, colorHex: String, sortOrder: Int) {
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    var color: Color { Color(hex: colorHex) }

    static let defaults: [(String, String, String)] = [
        ("Продукты", "🥑", "34C759"),
        ("Кафе и рестораны", "☕️", "FF9F0A"),
        ("Транспорт", "🚕", "0A84FF"),
        ("Дом", "🏠", "BF5AF2"),
        ("Здоровье", "💊", "FF453A"),
        ("Одежда", "👕", "64D2FF"),
        ("Развлечения", "🎮", "FF375F"),
        ("Другое", "🧾", "8E8E93")
    ]
}

@Model
final class Expense {
    var id: UUID
    var merchant: String
    var amount: Double
    var date: Date
    var itemsCount: Int
    var note: String
    /// "receipt" | "applepay" | "manual"
    var source: String
    /// nil = ещё не выбрана категория (ждёт выбора)
    var category: SpendCategory?

    init(merchant: String, amount: Double, date: Date = .now, itemsCount: Int = 1,
         note: String = "", source: String = "manual", category: SpendCategory? = nil) {
        self.id = UUID()
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.itemsCount = itemsCount
        self.note = note
        self.source = source
        self.category = category
    }
}

// MARK: - Общий контейнер (используется и приложением, и App Intents)

enum Store {
    static let container: ModelContainer = {
        let schema = Schema([SpendCategory.self, Expense.self])
        let container = try! ModelContainer(for: schema)
        seedIfNeeded(ModelContext(container))
        return container
    }()

    static func seedIfNeeded(_ ctx: ModelContext) {
        let count = (try? ctx.fetchCount(FetchDescriptor<SpendCategory>())) ?? 0
        guard count == 0 else { return }
        for (i, c) in SpendCategory.defaults.enumerated() {
            ctx.insert(SpendCategory(name: c.0, emoji: c.1, colorHex: c.2, sortOrder: i))
        }
        try? ctx.save()
    }
}

// MARK: - Хелперы

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

extension Double {
    /// 62,57 ₴
    var uah: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "ru_UA")
        return (f.string(from: NSNumber(value: self)) ?? "\(self)") + " ₴"
    }
}
