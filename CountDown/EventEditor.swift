import SwiftUI
import PhotosUI
import UIKit

struct EventEditor: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss
    private let existingEvent: CountEvent?

    @State private var title: String
    @State private var selectedDate: Date
    @State private var includesTime: Bool
    @State private var note: String
    @State private var unit: CountUnit
    @State private var showsMilestones: Bool
    @State private var palette: EventPalette
    @State private var symbol: String
    @State private var mask: PhotoMask
    @State private var maskOpacity: Double
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var removePhoto = false
    @State private var photoError = false

    private let symbols = ["sparkles", "heart.fill", "airplane", "gift.fill",
                           "graduationcap.fill", "figure.run", "sun.max.fill", "star.fill"]

    init(event: CountEvent? = nil) {
        existingEvent = event
        _title = State(initialValue: event?.title ?? "")
        _selectedDate = State(initialValue: event?.date.date() ?? .now)
        _includesTime = State(initialValue: event?.date.includesTime ?? false)
        _note = State(initialValue: event?.note ?? "")
        _unit = State(initialValue: event?.unit ?? .automatic)
        _showsMilestones = State(initialValue: event?.showsMilestones ?? true)
        _palette = State(initialValue: event?.palette ?? .coral)
        _symbol = State(initialValue: event?.symbol ?? "sparkles")
        _mask = State(initialValue: event?.mask ?? .black)
        _maskOpacity = State(initialValue: event?.maskOpacity ?? 0.55)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedImage: UIImage? {
        if removePhoto { return nil }
        return pendingImage ?? EventPhotoStore.image(named: existingEvent?.photoFilename)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Событие") {
                    TextField("Название события", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("eventTitle")
                    DatePicker("Дата", selection: $selectedDate, displayedComponents: .date)
                        .accessibilityIdentifier("eventDate")
                    Toggle("Указать время", isOn: $includesTime)
                    if includesTime {
                        DatePicker("Время", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    }
                    TextField("Заметка (необязательно)", text: $note, axis: .vertical)
                        .lineLimit(3...7)
                }

                Section {
                    Picker("Что показывать", selection: $unit) {
                        ForEach(CountUnit.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    Toggle("Круглые даты", isOn: $showsMilestones)
                } footer: {
                    Text("Автоматически: дни → часы за 24 часа → минуты за час до события. После события — дни. Круглые даты: 1, 7, 10, 30, 50, 100, 200 дней; месяц, полгода, год и юбилеи.")
                }

                Section("Фон") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(displayedImage == nil ? "Выбрать фотографию" : "Заменить фотографию",
                              systemImage: "photo")
                    }
                    if let displayedImage {
                        Image(uiImage: displayedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 145)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        Button("Убрать фотографию", role: .destructive) {
                            removePhoto = true
                            pendingImage = nil
                            selectedPhoto = nil
                        }
                    }
                    HStack(spacing: 12) {
                        ForEach(EventPalette.allCases) { option in
                            Button {
                                palette = option
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Circle()
                                    .fill(option.gradient)
                                    .frame(width: 42, height: 42)
                                    .overlay {
                                        if palette == option {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.title)
                            .accessibilityAddTraits(palette == option ? [.isSelected] : [])
                        }
                    }
                    Picker("Цвет затемнения", selection: $mask) {
                        ForEach(PhotoMask.allCases) { color in
                            Text(color.title).tag(color)
                        }
                    }
                    HStack {
                        Text("Затемнение")
                        Slider(value: $maskOpacity, in: 0.2...0.9, step: 0.05)
                        Text("\(Int(maskOpacity * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                    .disabled(displayedImage == nil)
                }

                Section("Символ") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(symbols, id: \.self) { option in
                            Button { symbol = option } label: {
                                Image(systemName: option)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .foregroundStyle(symbol == option ? .white : .primary)
                                    .background(symbol == option ? Color.accentColor : Color(uiColor: .tertiarySystemFill),
                                                in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option)
                            .accessibilityAddTraits(symbol == option ? [.isSelected] : [])
                        }
                    }
                }
            }
            .navigationTitle(existingEvent == nil ? "Новое событие" : "Изменить событие")
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
            .onChange(of: selectedPhoto) { _, selection in
                guard let selection else { return }
                Task {
                    do {
                        guard let data = try await selection.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else {
                            photoError = true
                            return
                        }
                        pendingImage = image
                        removePhoto = false
                    } catch {
                        photoError = true
                    }
                }
            }
            .alert("Не удалось открыть фото", isPresented: $photoError) {
                Button("ОК", role: .cancel) { }
            }
        }
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        let id = existingEvent?.id ?? UUID()
        var filename = existingEvent?.photoFilename
        if removePhoto {
            EventPhotoStore.remove(named: filename)
            filename = nil
        }
        if let pendingImage {
            filename = EventPhotoStore.save(pendingImage, for: id) ?? filename
        }

        let event = CountEvent(
            id: id, title: trimmedTitle,
            date: CalendarDay(date: selectedDate, includesTime: includesTime),
            palette: palette, symbol: symbol,
            note: note, unit: unit,
            showsMilestones: showsMilestones, photoFilename: filename,
            mask: mask, maskOpacity: maskOpacity
        )
        if existingEvent == nil { store.add(event) }
        else { store.update(event) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
