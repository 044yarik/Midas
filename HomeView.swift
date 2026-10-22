import SwiftUI
import SwiftData

enum Period: String, CaseIterable, Identifiable {
    case thisMonth = "Этот месяц", lastMonth = "Прошлый месяц", week = "7 дней", all = "Всё время"
    var id: String { rawValue }

    func contains(_ d: Date) -> Bool {
        let cal = Calendar.current
        switch self {
        case .thisMonth: return cal.isDate(d, equalTo: .now, toGranularity: .month)
        case .lastMonth:
            let last = cal.date(byAdding: .month, value: -1, to: .now)!
            return cal.isDate(d, equalTo: last, toGranularity: .month)
        case .week: return d >= cal.date(byAdding: .day, value: -7, to: .now)!
        case .all: return true
        }
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Expense.date, order: .reverse) private var all: [Expense]

    @State private var period: Period = .thisMonth
    @State private var showSettings = false
    @State private var showScanner = false
    @State private var showManual = false
    @State private var scanned: ParsedReceipt?
    @State private var showScanError = false

    private var expenses: [Expense] { all.filter { period.contains($0.date) } }
    private var total: Double { expenses.reduce(0) { $0 + $1.amount } }
    private var pending: [Expense] { expenses.filter { $0.category == nil } }

    private var byCategory: [(SpendCategory, Double)] {
        Dictionary(grouping: expenses.compactMap { e in e.category.map { ($0, e.amount) } }, by: { $0.0 })
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.1 }) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    Text("Финансы").font(.system(size: 40, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    periodChips
                    summaryCard
                    if !pending.isEmpty { pendingCard }
                    categoriesCard
                    purchasesCard
                    AccentButton(title: "Добавить расход", icon: "square.and.pencil") { showManual = true }
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 16)
            }
            ScanFAB { showScanner = true }
                .padding(.trailing, 20).padding(.bottom, 90)
        }
        .background(Theme.bg)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { result in
                if let result { scanned = result } else { showScanError = false }
            }.ignoresSafeArea()
        }
        .sheet(item: $scanned) { r in
            CategoryPickerSheet(merchant: r.merchant,
                                amountText: String(format: "%.2f", r.total).replacingOccurrences(of: ".", with: ","),
                                itemsCount: r.itemsCount, source: "receipt")
        }
        .sheet(isPresented: $showManual) {
            CategoryPickerSheet(merchant: "", amountText: "", source: "manual")
        }
    }

    // MARK: Блоки

    private var topBar: some View {
        HStack {
            Label("Добавить счёт", systemImage: "creditcard")
                .font(.headline).padding(.horizontal, 18).padding(.vertical, 14)
                .background(Theme.card, in: Capsule())
            Spacer()
            Button { showSettings = true } label: {
                HStack(spacing: 14) {
                    Text("UAH").font(.headline)
                    Image(systemName: "gearshape").font(.title3)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 14)
                .background(Theme.card, in: Capsule())
            }
        }
    }

    private var periodChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Period.allCases) { p in
                    Button { period = p } label: {
                        Text(p.rawValue).font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .background(period == p ? Theme.cardSoft : Theme.card, in: Capsule())
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(period == .thisMonth ? "В этом месяце вы потратили" : "Вы потратили")
                    .foregroundStyle(Theme.secondary)
                Text(total.uah).font(.system(size: 52, weight: .bold)).minimumScaleFactor(0.6)
                Text("\(expenses.count) чек.").font(.subheadline).foregroundStyle(Theme.secondary)
            }
        }
    }

    private var pendingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ждут категорию · \(pending.count)").font(.headline)
                ForEach(pending) { e in
                    HStack {
                        Text("\(e.merchant) · \(e.amount.uah)")
                        Spacer()
                        Menu("Выбрать") { categoryMenu(for: e) }
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder private func categoryMenu(for e: Expense) -> some View {
        let cats = (try? ctx.fetch(FetchDescriptor<SpendCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        ForEach(cats) { c in
            Button("\(c.emoji) \(c.name)") { e.category = c; try? ctx.save() }
        }
    }

    private var categoriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("По категориям").font(.title3.weight(.semibold))
                if byCategory.isEmpty {
                    Text("Пока пусто").foregroundStyle(Theme.secondary)
                }
                ForEach(byCategory, id: \.0.name) { cat, sum in
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(cat.emoji) \(cat.name)")
                            Spacer()
                            Text(sum.uah).fontWeight(.semibold)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondary)
                        }
                        GeometryReader { g in
                            Capsule().fill(cat.color)
                                .frame(width: g.size.width * (total > 0 ? sum / total : 0), height: 6)
                        }.frame(height: 6)
                    }
                }
            }
        }
    }

    private var purchasesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Покупки · \(expenses.count)").font(.title3.weight(.semibold))
                ForEach(expenses) { e in
                    HStack(spacing: 14) {
                        Text(e.category?.emoji ?? "❓").font(.title2)
                            .frame(width: 56, height: 56)
                            .background((e.category?.color ?? .gray).opacity(0.25),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.merchant).font(.headline)
                            Text("\(e.date.formatted(.dateTime.day().month(.abbreviated).year())) · \(e.itemsCount) поз.")
                                .font(.footnote).foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        Text(e.amount.uah).font(.headline)
                    }
                    .contextMenu {
                        Button(role: .destructive) { ctx.delete(e); try? ctx.save() } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
