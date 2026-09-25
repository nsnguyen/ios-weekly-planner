import SwiftUI

/// Add/delete quick-add event templates (Phase 42 #68).
struct TemplateEditorSheet: View {
    @Environment(\.eventTemplateStore) private var store
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.dismiss) private var dismiss

    @State private var records: [EventTemplateRecord] = []
    @State private var newTitle = ""
    @State private var newCategory: Category = .personal
    @State private var newDuration = 60

    var body: some View {
        NavigationStack {
            List {
                Section("Your quick-add buttons") {
                    ForEach(records, id: \.id) { record in
                        HStack {
                            Text(record.title)
                            Spacer()
                            Text("\(record.durationMinutes) min")
                                .foregroundStyle(.secondary)
                            Button(role: .destructive) {
                                try? store?.delete(id: record.id)
                                reload()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .accessibilityIdentifier(AccessibilityIDs.templateEditorDelete(record.id))
                        }
                    }
                }
                Section("Add new") {
                    TextField("Title (e.g. Swim)", text: $newTitle)
                        .accessibilityIdentifier(AccessibilityIDs.templateEditorTitleField)
                    Picker("Category", selection: $newCategory) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Text(CategoryPalette.displayName(category))
                        }
                    }
                    Stepper("Duration: \(newDuration) min", value: $newDuration, in: 15 ... 240, step: 15)
                    Button("Add") {
                        let title = newTitle.trimmingCharacters(in: .whitespaces)
                        guard !title.isEmpty else { return }
                        try? store?.add(title: title, category: newCategory, durationMinutes: newDuration)
                        newTitle = ""
                        reload()
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier(AccessibilityIDs.templateEditorAdd)
                }
            }
            .navigationTitle("Quick-Add Buttons")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { reload() }
    }

    private func reload() {
        records = (try? store?.templates()) ?? []
    }
}
