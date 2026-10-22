import AppIntents
import ActivityKit
import SwiftData
import UserNotifications

// MARK: - Атрибуты Live Activity (Dynamic Island)

struct ExpenseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// До 4 быстрых категорий: "🥑|Продукты"
        var options: [String]
        var chosen: String?          // "🥑 Продукты", когда выбрано
    }
    var expenseID: String
    var merchant: String
    var amount: Double
}

// MARK: - 1. Интент для автоматизации «Apple Pay» (Команды → Автоматизация → Транзакция)

struct LogApplePayIntent: AppIntent {
    static var title: LocalizedStringResource = "Записать оплату Apple Pay"
    static var description = IntentDescription("Сохраняет трату и предлагает выбрать категорию.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Сумма") var amount: Double
    @Parameter(title: "Магазин") var merchant: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let ctx = Store.container.mainContext
        let expense = Expense(merchant: merchant.isEmpty ? "Apple Pay" : merchant,
                              amount: amount, source: "applepay")
        ctx.insert(expense)
        try? ctx.save()

        let cats = (try? ctx.fetch(FetchDescriptor<SpendCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        PaymentPrompt.show(expense: expense, categories: cats)
        return .result()
    }
}

// MARK: - 2. Кнопка категории внутри Dynamic Island

struct SetCategoryIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Выбрать категорию"

    @Parameter(title: "ID траты") var expenseID: String
    @Parameter(title: "Категория") var categoryName: String

    init() {}
    init(expenseID: String, categoryName: String) {
        self.expenseID = expenseID
        self.categoryName = categoryName
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        PaymentPrompt.assign(expenseID: expenseID, categoryName: categoryName)
        for activity in Activity<ExpenseActivityAttributes>.activities where activity.attributes.expenseID == expenseID {
            let done = ActivityContent(
                state: .init(options: [], chosen: categoryName),
                staleDate: nil)
            await activity.end(done, dismissalPolicy: .after(.now + 3))
        }
        return .result()
    }
}

// MARK: - Показ запроса: Live Activity + уведомление с кнопками (запасной вариант)

enum PaymentPrompt {
    static let notifCategory = "PICK_CATEGORY"

    @MainActor
    static func show(expense: Expense, categories: [SpendCategory]) {
        let top = categories.prefix(4).map { "\($0.emoji)|\($0.name)" }

        // Dynamic Island. Работает, если iOS разрешает старт активности из текущего контекста.
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attrs = ExpenseActivityAttributes(expenseID: expense.id.uuidString,
                                                  merchant: expense.merchant,
                                                  amount: expense.amount)
            let content = ActivityContent(state: ExpenseActivityAttributes.ContentState(options: Array(top), chosen: nil),
                                          staleDate: .now + 600)
            _ = try? Activity.request(attributes: attrs, content: content)
        }

        // Запасной путь: обычное уведомление с кнопками категорий (долгое нажатие / раскрытие).
        let actions = categories.prefix(4).map {
            UNNotificationAction(identifier: $0.name, title: "\($0.emoji) \($0.name)", options: [])
        }
        let cat = UNNotificationCategory(identifier: notifCategory, actions: actions,
                                         intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])

        let c = UNMutableNotificationContent()
        c.title = "\(expense.amount.uah) · \(expense.merchant)"
        c.body = "В какую категорию добавить?"
        c.categoryIdentifier = notifCategory
        c.userInfo = ["expenseID": expense.id.uuidString]
        let req = UNNotificationRequest(identifier: expense.id.uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    @MainActor
    static func assign(expenseID: String, categoryName: String) {
        let ctx = Store.container.mainContext
        let all = (try? ctx.fetch(FetchDescriptor<Expense>())) ?? []
        guard let e = all.first(where: { $0.id.uuidString == expenseID }) else { return }
        let cats = (try? ctx.fetch(FetchDescriptor<SpendCategory>())) ?? []
        e.category = cats.first { $0.name == categoryName }
        try? ctx.save()
    }
}

// MARK: - Обработчик нажатий на кнопки уведомления

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["expenseID"] as? String else { return }
        let name = response.actionIdentifier
        guard name != UNNotificationDefaultActionIdentifier,
              name != UNNotificationDismissActionIdentifier else { return }
        await MainActor.run { PaymentPrompt.assign(expenseID: id, categoryName: name) }
    }
}

// MARK: - Быстрые команды (чтобы интент был виден в приложении «Команды»)

struct MIDASShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogApplePayIntent(),
                    phrases: ["Записать оплату в \(.applicationName)"],
                    shortTitle: "Оплата Apple Pay",
                    systemImageName: "creditcard")
    }
}
