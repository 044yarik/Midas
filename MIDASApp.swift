import SwiftUI
import SwiftData
import UserNotifications

@main
struct MIDASApp: App {
    private let notifDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notifDelegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(Store.container)
    }
}

struct RootView: View {
    @State private var tab = 0
    @State private var showScanner = false
    @State private var scanned: ParsedReceipt?

    var body: some View {
        TabView(selection: $tab) {
            HomeView().tabItem { Label("Главная", systemImage: "house.fill") }.tag(0)
            ReportsView().tabItem { Label("Отчёты", systemImage: "chart.bar.fill") }.tag(1)
            SearchView().tabItem { Label("Поиск", systemImage: "magnifyingglass") }.tag(2)
        }
    }
}

struct SearchView: View {
    @Query(sort: \Expense.date, order: .reverse) private var all: [Expense]
    @State private var text = ""

    private var results: [Expense] {
        text.isEmpty ? all : all.filter {
            $0.merchant.localizedCaseInsensitiveContains(text)
            || ($0.category?.name.localizedCaseInsensitiveContains(text) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { e in
                HStack {
                    Text(e.category?.emoji ?? "❓")
                    VStack(alignment: .leading) {
                        Text(e.merchant)
                        Text(e.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.footnote).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    Text(e.amount.uah).fontWeight(.semibold)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Поиск")
            .searchable(text: $text, prompt: "Магазин или категория")
        }
    }
}
