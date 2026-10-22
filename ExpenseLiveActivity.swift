import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

@main
struct MIDASWidgetBundle: WidgetBundle {
    var body: some Widget { ExpenseLiveActivity() }
}

struct ExpenseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExpenseActivityAttributes.self) { context in
            // Экран блокировки / баннер
            VStack(alignment: .leading, spacing: 10) {
                header(context)
                CategoryButtons(context: context)
            }
            .padding(16)
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.merchant).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(format(context.attributes.amount)).font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CategoryButtons(context: context)
                }
            } compactLeading: {
                Image(systemName: "creditcard.fill").foregroundStyle(Color(red: 0.89, green: 0.69, blue: 0.29))
            } compactTrailing: {
                Text(format(context.attributes.amount)).font(.caption2)
            } minimal: {
                Image(systemName: "creditcard.fill")
            }
        }
    }

    private func header(_ c: ActivityViewContext<ExpenseActivityAttributes>) -> some View {
        HStack {
            Text(c.attributes.merchant).font(.headline)
            Spacer()
            Text(format(c.attributes.amount)).font(.headline)
        }
    }

    private func format(_ v: Double) -> String { String(format: "%.2f ₴", v).replacingOccurrences(of: ".", with: ",") }
}

struct CategoryButtons: View {
    let context: ActivityViewContext<ExpenseActivityAttributes>

    var body: some View {
        if let chosen = context.state.chosen {
            Label("Добавлено: \(chosen)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("В какую категорию добавить?").font(.caption).foregroundStyle(.secondary)
                let opts = context.state.options.map { $0.split(separator: "|", maxSplits: 1).map(String.init) }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(opts.enumerated()), id: \.offset) { _, o in
                        if o.count == 2 {
                            Button(intent: SetCategoryIntent(expenseID: context.attributes.expenseID, categoryName: o[1])) {
                                Text("\(o[0]) \(o[1])").font(.footnote).lineLimit(1)
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent).tint(.gray.opacity(0.4))
                        }
                    }
                }
            }
        }
    }
}
