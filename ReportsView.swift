import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Query(sort: \Expense.date) private var all: [Expense]
    @State private var selectedMonth: Date = Calendar.current.startOfMonth(for: .now)

    private var months: [Date] {
        let cal = Calendar.current
        return (0..<6).reversed().map { cal.date(byAdding: .month, value: -$0, to: cal.startOfMonth(for: .now))! }
    }

    private func sum(in month: Date) -> Double {
        all.filter { Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthExpenses: [Expense] {
        all.filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) && $0.category != nil }
    }

    private var slices: [(SpendCategory, Double)] {
        Dictionary(grouping: monthExpenses, by: { $0.category! })
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
    }

    private var total: Double { slices.reduce(0) { $0 + $1.1 } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Отчёты").font(.headline).padding(.top, 8)

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("По месяцам").font(.title3.weight(.semibold))
                        Chart(months, id: \.self) { m in
                            BarMark(x: .value("Месяц", m, unit: .month), y: .value("₴", sum(in: m)))
                                .foregroundStyle(Calendar.current.isDate(m, equalTo: selectedMonth, toGranularity: .month)
                                                 ? Color.white.opacity(0.9) : Color.white.opacity(0.35))
                                .cornerRadius(6)
                        }
                        .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
                        .chartXSelection(value: Binding<Date?>(get: { nil }, set: { if let d = $0 { selectedMonth = Calendar.current.startOfMonth(for: d) } }))
                        .frame(height: 220)
                        Text("Нажмите на столбец, чтобы выбрать месяц")
                            .font(.footnote).foregroundStyle(Theme.secondary)
                    }
                }

                Card {
                    VStack(spacing: 14) {
                        Chart(slices, id: \.0.name) { cat, value in
                            SectorMark(angle: .value("₴", value), innerRadius: .ratio(0.55), angularInset: 1)
                                .foregroundStyle(cat.color)
                        }
                        .frame(height: 280)
                        .chartBackground { _ in
                            VStack {
                                Text("Всего").font(.subheadline).foregroundStyle(Theme.secondary)
                                Text(total.uah).font(.title.bold())
                            }
                        }
                        ForEach(slices, id: \.0.name) { cat, value in
                            HStack {
                                Circle().fill(cat.color).frame(width: 12, height: 12)
                                Text("\(cat.emoji) \(cat.name)")
                                Spacer()
                                Text("\(Int((total > 0 ? value / total : 0) * 100))%").foregroundStyle(Theme.secondary)
                                Text(value.uah).fontWeight(.semibold).frame(minWidth: 90, alignment: .trailing)
                            }
                        }
                    }
                }
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 16)
        }
        .background(Theme.bg)
    }
}

extension Calendar {
    func startOfMonth(for d: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: d))!
    }
}
