import SwiftUI
import UIKit

struct EventEditor: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss
    private let existingEvent: CountEvent?

    @State private var title: String
    @State private var selectedDate: Date
    @State private var palette: EventPalette
    @State private var symbol: String

    private let symbols = ["sparkles", "heart.fill", "airplane", "gift.fill", "graduationcap.fill", "figure.run", "sun.max.fill", "star.fill"]

    init(event: CountEvent? = nil) {
        existingEvent = event
        _title = State(initialValue: event?.title ?? "")
        _selectedDate = State(initialValue: event?.date.date() ?? .now)
        _palette = State(initialValue: event?.palette ?? .coral)
        _symbol = State(initialValue: event?.symbol ?? "sparkles")
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Событие") {
                    TextField("Например, путешествие", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("eventTitle")
                    DatePicker("Дата", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("eventDate")
                }

                Section("Цвет") {
                    HStack(spacing: 12) {
                        ForEach(EventPalette.allCases) { option in
                            Button {
                                palette = option
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Circle()
                                    .fill(option.gradient)
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        if palette == option {
                                            Image(systemName: "checkmark")
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.title)
                            .accessibilityAddTraits(palette == option ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("Символ") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(symbols, id: \.self) { option in
                            Button {
                                symbol = option
                            } label: {
                                Image(systemName: option)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .foregroundStyle(symbol == option ? Color.white : Color.primary)
                                    .background(symbol == option ? Color.accentColor : Color(uiColor: .tertiarySystemFill),
                                                in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option)
                            .accessibilityAddTraits(symbol == option ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(existingEvent == nil ? "Новое событие" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .bold()
                        .disabled(trimmedTitle.isEmpty)
                        .accessibilityIdentifier("saveEvent")
                }
            }
        }
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        let updated = CountEvent(
            id: existingEvent?.id ?? UUID(),
            title: trimmedTitle,
            date: CalendarDay(date: selectedDate),
            palette: palette,
            symbol: symbol
        )
        if existingEvent == nil {
            store.add(updated)
        } else {
            store.update(updated)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
