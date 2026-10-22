import SwiftUI
import SwiftData

/// Лист подтверждения: показывает распознанную трату и даёт выбрать категорию.
struct CategoryPickerSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]

    @State var merchant: String
    @State var amountText: String
    var itemsCount: Int = 1
    var source: String = "receipt"

    @State private var selected: SpendCategory?

    private let cols = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Магазин", text: $merchant)
                                .font(.title3.weight(.semibold))
                            Divider()
                            HStack {
                                TextField("0,00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 40, weight: .bold))
                                Text("₴").font(.system(size: 40, weight: .bold))
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Категория").font(.headline)
                            LazyVGrid(columns: cols, spacing: 10) {
                                ForEach(categories) { c in
                                    Button { selected = c } label: {
                                        HStack {
                                            Text(c.emoji)
                                            Text(c.name).lineLimit(1)
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 14).padding(.vertical, 14)
                                        .background(selected == c ? c.color.opacity(0.35) : Theme.cardSoft,
                                                    in: Capsule())
                                        .overlay(Capsule().stroke(selected == c ? c.color : .clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Новая трата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save).disabled(parsedAmount == nil || selected == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        guard let a = parsedAmount else { return }
        ctx.insert(Expense(merchant: merchant.isEmpty ? "Без названия" : merchant,
                           amount: a, itemsCount: itemsCount, source: source, category: selected))
        try? ctx.save()
        dismiss()
    }
}
