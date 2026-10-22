import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @AppStorage("weeklySummary") private var weekly = false
    @AppStorage("dailyReminder") private var daily = false
    @AppStorage("incomeEnabled") private var income = false
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack { Label("Язык", systemImage: "globe"); Spacer()
                        Text("RU  Русский").foregroundStyle(Theme.secondary) }
                }
                Section("Уведомления") {
                    Toggle(isOn: $weekly) { Label("Еженедельная сводка", systemImage: "calendar") }
                    Toggle(isOn: $daily) { Label("Ежедневное напоминание", systemImage: "bell") }
                        .onChange(of: daily) { _, on in if on { Self.scheduleDaily() } else { Self.cancelDaily() } }
                }
                Section { Toggle(isOn: $income) { Label("Доходы", systemImage: "plus.circle") } }

                Section {
                    NavigationLink { ApplePaySetupView() } label: { Label("Apple Pay", systemImage: "creditcard") }
                }
                Section {
                    Link(destination: URL(string: "mailto:support@example.com")!) { Text("Написать в поддержку") }
                }
                Section {
                    HStack { Text("Версия"); Spacer()
                        Text("1.0 (1)").foregroundStyle(Theme.secondary) }
                }
                Section {
                    Button(role: .destructive) { confirmClear = true } label: {
                        Label("Очистить историю", systemImage: "trash")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Настройки").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .confirmationDialog("Удалить все траты?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    try? ctx.delete(model: Expense.self); try? ctx.save()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    static func scheduleDaily() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let c = UNMutableNotificationContent()
            c.title = "MIDAS"; c.body = "Не забудьте записать сегодняшние траты"
            var d = DateComponents(); d.hour = 21
            let t = UNCalendarNotificationTrigger(dateMatching: d, repeats: true)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "daily", content: c, trigger: t))
        }
    }
    static func cancelDaily() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily"])
    }
}

// MARK: - Настройка Apple Pay → Dynamic Island

struct ApplePaySetupView: View {
    @State private var notifStatus = "…"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("После оплаты Apple Pay на Dynamic Island появится выбор категории.")
                    .foregroundStyle(Theme.secondary)

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Настройка (1 минута)").font(.headline)
                        step(1, "Откройте приложение «Команды» → вкладка «Автоматизация» → «+».")
                        step(2, "Выберите триггер «Транзакция» (Wallet) и отметьте нужные карты.")
                        step(3, "Действие: «Записать оплату Apple Pay» из MIDAS.")
                        step(4, "В поле «Сумма» подставьте переменную «Сумма» из транзакции, в «Магазин» — «Продавец».")
                        step(5, "Включите «Запускать немедленно» и отключите «Уведомлять при запуске».")
                    }
                }

                Button {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
                        DispatchQueue.main.async { notifStatus = ok ? "Разрешено" : "Запрещено" }
                    }
                } label: {
                    HStack { Text("Разрешить уведомления"); Spacer(); Text(notifStatus).foregroundStyle(Theme.secondary) }
                        .padding(18).background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
                }.buttonStyle(.plain)

                Link(destination: URL(string: "shortcuts://create-automation")!) {
                    Text("Открыть «Команды»").font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(Theme.accent, in: Capsule())
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("Apple Pay").navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.footnote.bold()).frame(width: 24, height: 24)
                .background(Theme.accent, in: Circle()).foregroundStyle(.black)
            Text(t)
        }
    }
}
