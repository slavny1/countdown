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
    @State private var maskColorHex: String
    @State private var photoZoom: Double
    @State private var photoFocusX: Double
    @State private var photoFocusY: Double
    @State private var countsUp: Bool
    @State private var maskOpacity: Double
    @State private var style: CardStyle
    @State private var showCustomizer = false
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
        _maskColorHex = State(initialValue: event?.maskColorHex ?? "000000")
        _photoZoom = State(initialValue: event?.photoZoom ?? 1)
        _photoFocusX = State(initialValue: event?.photoFocusX ?? 0.5)
        _photoFocusY = State(initialValue: event?.photoFocusY ?? 0.5)
        _countsUp = State(initialValue: event?.countsUp ?? false)
        _maskOpacity = State(initialValue: event?.maskOpacity ?? 0.55)
        _style = State(initialValue: event?.style ?? CardStyle())
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedImage: UIImage? {
        if removePhoto { return nil }
        return pendingImage ?? EventPhotoStore.image(named: existingEvent?.photoFilename)
    }

    private var previewEvent: CountEvent {
        CountEvent(id: existingEvent?.id ?? UUID(),
                   title: trimmedTitle.isEmpty ? "Моё событие" : trimmedTitle,
                   date: CalendarDay(date: selectedDate, includesTime: includesTime, includesSeconds: includesTime),
                   palette: palette, symbol: symbol, note: note, unit: unit,
                   showsMilestones: showsMilestones,
                   photoFilename: removePhoto ? nil : existingEvent?.photoFilename,
                   mask: mask, maskOpacity: maskOpacity,
                   maskColorHex: maskColorHex, photoZoom: photoZoom,
                   photoFocusX: photoFocusX, photoFocusY: photoFocusY,
                   style: style, countsUp: countsUp)
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
                    HStack {
                        Spacer()
                        Button {
                            selectedDate = .now
                            includesTime = true
                        } label: {
                            Label("Сейчас", systemImage: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)
                    }
                    Toggle("Считать время с этой даты", isOn: $countsUp)
                    if countsUp {
                        Button {
                            selectedDate = .now
                            includesTime = true
                        } label: {
                            Label("Начать заново с текущего момента", systemImage: "arrow.counterclockwise")
                        }
                        .accessibilityIdentifier("restartCounter")
                    }
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

                Section("Оформление и фото") {
                    Button {
                        showCustomizer = true
                    } label: {
                        HStack {
                            Label("Открыть редактор карточки и виджетов",
                                  systemImage: "slider.horizontal.3")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .accessibilityIdentifier("customizeCard")
                    WidgetCardPreview(event: previewEvent, image: displayedImage, wide: true)
                        .frame(height: 158)
                        .allowsHitTesting(false)
                }

                Section("Символ") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(symbols, id: \.self) { option in
                            Button { symbol = option } label: {
                                Image(systemName: option)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .foregroundStyle(symbol == option ? Color.white : Color.primary)
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

            .sheet(isPresented: $showCustomizer) {
                CardStyleCustomizer(style: $style, palette: $palette,
                                    maskColorHex: $maskColorHex, maskOpacity: $maskOpacity,
                                    photoZoom: $photoZoom, photoFocusX: $photoFocusX,
                                    photoFocusY: $photoFocusY,
                                    selectedPhoto: $selectedPhoto, pendingImage: $pendingImage,
                                    removePhoto: $removePhoto, previewEvent: previewEvent)
            }
            .alert("Не удалось сохранить фото", isPresented: $photoError) {
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
            guard let savedName = EventPhotoStore.save(pendingImage, for: id) else {
                photoError = true
                return
            }
            filename = savedName
        }

        let event = CountEvent(
            id: id, title: trimmedTitle,
            date: CalendarDay(date: selectedDate, includesTime: includesTime, includesSeconds: includesTime),
            palette: palette, symbol: symbol,
            note: note, unit: unit,
            showsMilestones: showsMilestones, photoFilename: filename,
            mask: mask, maskOpacity: maskOpacity,
            maskColorHex: maskColorHex, photoZoom: photoZoom,
            photoFocusX: photoFocusX, photoFocusY: photoFocusY,
            style: style, countsUp: countsUp
        )
        if existingEvent == nil { store.add(event) }
        else { store.update(event) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
