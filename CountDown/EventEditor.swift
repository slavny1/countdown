import SwiftUI
import PhotosUI
import UIKit

private enum EventColorTarget: String, Identifiable {
    case text, background, mask
    var id: String { rawValue }
}

/// Event editing lives below a persistent, interactive visual preview.
struct EventEditor: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss

    private let existingEvent: CountEvent?
    @State private var title: String
    @State private var selectedDate: Date
    @State private var includesTime: Bool
    @State private var note: String
    @State private var displayUnits: TimeUnitSelection
    @State private var showsMilestones: Bool
    @State private var palette: EventPalette
    @State private var symbol: String
    @State private var maskColorHex: String
    @State private var maskOpacity: Double
    @State private var backgroundColorHex: String?
    @State private var photoZoom: Double
    @State private var photoFocusX: Double
    @State private var photoFocusY: Double
    @State private var style: CardStyle

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var removePhoto = false
    @State private var photoError = false
    @FocusState private var noteIsFocused: Bool
    @State private var showStyle = false
    @State private var showFonts = false
    @State private var showColors = false
    @State private var showBackground = false
    @State private var showingCustomColor: EventColorTarget?
    @State private var pickedColor = Color.white
    @State private var customText: [String] = []
    @State private var customBackgrounds: [String] = []
    @State private var customMasks: [String] = []

    private let symbols = ["sparkles", "heart.fill", "airplane", "gift.fill",
                           "graduationcap.fill", "figure.run", "sun.max.fill",
                           "star.fill", "moon.stars.fill", "flag.fill", "party.popper.fill"]
    private let textColors = ["FFFFFF", "1B2029", "F6CF59", "C8E9FF"]
    private let maskColors = ["141414", "142957", "F0E3D1", "FFFFFF"]
    private let backgroundColors = ["F0E3D1", "1B2029", "5373B9", "E6A681"]

    init(event: CountEvent? = nil) {
        existingEvent = event
        _title = State(initialValue: event?.title ?? "")
        _selectedDate = State(initialValue: event?.date.date() ?? .now)
        _includesTime = State(initialValue: event?.date.includesTime ?? false)
        _note = State(initialValue: event?.note ?? "")
        _displayUnits = State(initialValue: event?.displayUnits ?? TimeUnitSelection())
        _showsMilestones = State(initialValue: event?.showsMilestones ?? true)
        _palette = State(initialValue: event?.palette ?? .coral)
        _symbol = State(initialValue: event?.symbol ?? "sparkles")
        _maskColorHex = State(initialValue: event?.maskColorHex ?? "000000")
        _maskOpacity = State(initialValue: event?.maskOpacity ?? 0.55)
        _backgroundColorHex = State(initialValue: event?.backgroundColorHex)
        _photoZoom = State(initialValue: event?.photoZoom ?? 1)
        _photoFocusX = State(initialValue: event?.photoFocusX ?? 0.5)
        _photoFocusY = State(initialValue: event?.photoFocusY ?? 0.5)
        _style = State(initialValue: event?.style ?? CardStyle())
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var image: UIImage? {
        if removePhoto { return nil }
        return pendingImage ?? EventPhotoStore.image(named: existingEvent?.photoFilename)
    }

    private var previewEvent: CountEvent {
        CountEvent(
            id: existingEvent?.id ?? UUID(),
            title: trimmedTitle.isEmpty ? "Моё событие" : trimmedTitle,
            date: CalendarDay(date: selectedDate, includesTime: includesTime,
                              includesSeconds: includesTime),
            palette: palette,
            symbol: symbol,
            note: note,
            unit: .automatic,
            showsMilestones: showsMilestones,
            photoFilename: removePhoto ? nil : existingEvent?.photoFilename,
            maskOpacity: maskOpacity,
            maskColorHex: maskColorHex,
            photoZoom: photoZoom,
            photoFocusX: photoFocusX,
            photoFocusY: photoFocusY,
            backgroundColorHex: backgroundColorHex,
            isPinned: existingEvent?.isPinned ?? false,
            style: style,
            countsUp: existingEvent?.countsUp ?? false,
            displayUnits: displayUnits
        )
    }

    private var weightIndex: Binding<Double> {
        let options = CardThickness.allCases
        return Binding(
            get: { Double(options.firstIndex(of: style.thickness) ?? 4) },
            set: { style.thickness = options[min(max(Int($0.rounded()), 0), options.count - 1)] }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    EventCard(event: previewEvent, now: context.date, previewImage: image)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                        .animation(.easeInOut(duration: 0.25), value: style)
                        .animation(.easeInOut(duration: 0.25), value: title)
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(Color(uiColor: .systemGroupedBackground))

                Form {
                    eventFields
                    countFields
                    appearanceFields
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(existingEvent == nil ? "Новое событие" : "Изменить событие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { noteIsFocused = false }
                }
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
            .sheet(item: $showingCustomColor) { target in
                NavigationStack {
                    Form {
                        ColorPicker("Выбери цвет", selection: $pickedColor, supportsOpacity: false)
                    }
                    .navigationTitle("Добавить цвет")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") { showingCustomColor = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Добавить") {
                                saveCustomColor(target)
                                showingCustomColor = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                customText = UserDefaults.standard.stringArray(forKey: "days.customTextColors") ?? []
                customBackgrounds = UserDefaults.standard.stringArray(forKey: "days.customBackgrounds") ?? []
                customMasks = UserDefaults.standard.stringArray(forKey: "days.customMasks") ?? []
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let newImage = UIImage(data: data) else {
                        photoError = true
                        return
                    }
                    pendingImage = newImage
                    removePhoto = false
                }
            }
            .alert("Не удалось сохранить фото", isPresented: $photoError) {
                Button("ОК", role: .cancel) {}
            }
        }
    }

    private var eventFields: some View {
                    Section("Событие") {
                        TextField("Название события", text: $title)
                            .textInputAutocapitalization(.sentences)
                            .onChange(of: title) { _, value in
                                if value.count > 70 { title = String(value.prefix(70)) }
                            }
                            .accessibilityIdentifier("eventTitle")
                        HStack(spacing: 10) {
                            DatePicker("Дата", selection: $selectedDate,
                                       displayedComponents: .date)
                                .accessibilityIdentifier("eventDate")
                            Button("Сейчас") {
                                selectedDate = .now
                                includesTime = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("setNow")
                        }
                        Toggle("Указать время", isOn: $includesTime)
                        if includesTime {
                            DatePicker("Время", selection: $selectedDate,
                                       displayedComponents: .hourAndMinute)
                        }
                        TextField("Заметка (необязательно)", text: $note, axis: .vertical)
                            .lineLimit(3...7)
                            .focused($noteIsFocused)
                            .onChange(of: note) { _, value in
                                if value.count > 300 { note = String(value.prefix(300)) }
                            }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(symbols, id: \.self) { value in
                                    Button {
                                        symbol = value
                                    } label: {
                                        Image(systemName: value)
                                            .font(.title3)
                                            .frame(width: 45, height: 45)
                                            .foregroundStyle(symbol == value ? Color.white : Color.primary)
                                            .background(symbol == value ? Color.accentColor :
                                                        Color(uiColor: .tertiarySystemFill),
                                                        in: RoundedRectangle(cornerRadius: 13))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(value)
                                }
                            }
                        }
                    }

    }

    private var countFields: some View {
                    Section("Отсчёт") {
                        Toggle("Автоматически", isOn: $displayUnits.automatic)
                        if !displayUnits.automatic {
                            toggleUnit(.days, title: "Дни")
                            toggleUnit(.hours, title: "Часы")
                            toggleUnit(.minutes, title: "Минуты")
                        }
                        Toggle("Круглые даты", isOn: $showsMilestones)
                    }

    }

    private var appearanceFields: some View {
                    Section {
                        DisclosureGroup("Оформление", isExpanded: $showStyle) {
                            DisclosureGroup("Шрифт", isExpanded: $showFonts) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(CardTypeface.allCases) { face in
                                            Button {
                                                style.typeface = face
                                            } label: {
                                                VStack(spacing: 3) {
                                                    Text("123")
                                                        .font(.system(size: 31, weight: style.thickness.fontWeight,
                                                                      design: face.fontDesign))
                                                    Text(face.title).font(.caption2)
                                                }
                                                .foregroundStyle(style.typeface == face ? Color.accentColor : Color.primary)
                                                .frame(width: 92, height: 73)
                                                .background(Color(uiColor: .tertiarySystemFill),
                                                            in: RoundedRectangle(cornerRadius: 13))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                HStack {
                                    Text("Размер")
                                    Slider(value: $style.scale, in: 0.7...1.6)
                                    Text("\(Int(style.scale * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .frame(width: 46)
                                }
                                HStack {
                                    Text("Толщина")
                                    Slider(value: weightIndex, in: 0...5, step: 1)
                                    Text(style.thickness.title)
                                        .font(.caption)
                                        .frame(width: 85, alignment: .trailing)
                                }
                            }
                            DisclosureGroup("Цвета", isExpanded: $showColors) {
                                Text("Цвет текста").font(.subheadline)
                                swatchRow(textColors, custom: customText,
                                          selected: style.textColorHex, target: .text)
                            }
                            DisclosureGroup("Фон", isExpanded: $showBackground) {
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Label(image == nil ? "Выбрать фото" : "Заменить фото",
                                          systemImage: "photo")
                                }
                                if image != nil {
                                    Button("Удалить фото", role: .destructive) {
                                        pendingImage = nil
                                        selectedPhoto = nil
                                        removePhoto = true
                                        backgroundColorHex = nil
                                    }
                                    Text("Цвет затемнения").font(.subheadline)
                                    swatchRow(maskColors, custom: customMasks,
                                              selected: maskColorHex, target: .mask)
                                    HStack {
                                        Text("Непрозрачность")
                                        Slider(value: $maskOpacity, in: 0...0.9)
                                    }
                                    HStack {
                                        Text("Масштаб")
                                        Slider(value: $photoZoom, in: 1...2.5)
                                    }
                                } else {
                                    Text("Градиент").font(.subheadline)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(EventPalette.allCases) { option in
                                                Button {
                                                    palette = option
                                                    backgroundColorHex = nil
                                                } label: {
                                                    Circle()
                                                        .fill(option.gradient)
                                                        .frame(width: 43, height: 43)
                                                        .overlay {
                                                            if palette == option && backgroundColorHex == nil {
                                                                Image(systemName: "checkmark")
                                                                    .foregroundStyle(.white)
                                                            }
                                                        }
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel(option.title)
                                            }
                                        }
                                    }
                                    Text("Цвет фона").font(.subheadline)
                                    swatchRow(backgroundColors, custom: customBackgrounds,
                                              selected: backgroundColorHex ?? "", target: .background)
                                }
                            }
                        }
                    }

    }

    private func toggleUnit(_ unit: CountUnit, title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: {
                switch unit {
                case .days: displayUnits.days
                case .hours: displayUnits.hours
                case .minutes: displayUnits.minutes
                case .automatic: false
                }
            },
            set: { displayUnits.select(unit, enabled: $0) }
        ))
    }

    private func swatchRow(_ basics: [String], custom: [String], selected: String,
                           target: EventColorTarget) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(basics + custom.filter { !basics.contains($0) }, id: \.self) { hex in
                    Button {
                        switch target {
                        case .text: style.textColorHex = hex
                        case .background: backgroundColorHex = hex
                        case .mask: maskColorHex = hex
                        }
                    } label: {
                        Circle()
                            .fill(Color(rgbHex: hex))
                            .frame(width: 43, height: 43)
                            .overlay(Circle().strokeBorder(.gray.opacity(0.2)))
                            .overlay {
                                if selected == hex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(hex == "1B2029" || hex == "141414" ||
                                                         hex == "142957" ? Color.white : Color.black)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    let hex: String
                    switch target {
                    case .text: hex = style.textColorHex
                    case .background: hex = backgroundColorHex ?? "FFFFFF"
                    case .mask: hex = maskColorHex
                    }
                    pickedColor = Color(rgbHex: hex)
                    showingCustomColor = target
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 43, height: 43)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel("Добавить свой цвет")
            }
        }
        .frame(height: 50)
    }

    private func saveCustomColor(_ target: EventColorTarget) {
        let hex = pickedColor.rgbHex
        switch target {
        case .text:
            style.textColorHex = hex
            if !customText.contains(hex) { customText.append(hex) }
            UserDefaults.standard.set(customText, forKey: "days.customTextColors")
        case .background:
            backgroundColorHex = hex
            if !customBackgrounds.contains(hex) { customBackgrounds.append(hex) }
            UserDefaults.standard.set(customBackgrounds, forKey: "days.customBackgrounds")
        case .mask:
            maskColorHex = hex
            if !customMasks.contains(hex) { customMasks.append(hex) }
            UserDefaults.standard.set(customMasks, forKey: "days.customMasks")
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
            guard let newName = EventPhotoStore.save(pendingImage, for: id) else {
                photoError = true
                return
            }
            filename = newName
        }
        let event = CountEvent(
            id: id,
            title: trimmedTitle,
            date: CalendarDay(date: selectedDate, includesTime: includesTime,
                              includesSeconds: includesTime),
            palette: palette,
            symbol: symbol,
            note: note,
            unit: .automatic,
            showsMilestones: showsMilestones,
            photoFilename: filename,
            maskOpacity: maskOpacity,
            maskColorHex: maskColorHex,
            photoZoom: photoZoom,
            photoFocusX: photoFocusX,
            photoFocusY: photoFocusY,
            backgroundColorHex: backgroundColorHex,
            isPinned: existingEvent?.isPinned ?? false,
            style: style,
            countsUp: existingEvent?.countsUp ?? false,
            displayUnits: displayUnits
        )
        if existingEvent == nil { store.add(event) }
        else { store.update(event) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
