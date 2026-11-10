import SwiftUI
import PhotosUI
import UIKit

private enum WidgetEditorRoute: Identifiable {
    case create, edit(WidgetPreset)
    var id: String {
        switch self {
        case .create: "create"
        case .edit(let preset): preset.id.uuidString
        }
    }
    var preset: WidgetPreset? {
        if case .edit(let preset) = self { return preset }
        return nil
    }
}

/// App-side gallery. WidgetKit does not allow applications to place widgets
/// directly on the Home Screen; a saved preset appears in Edit Widget → Оформление.
struct WidgetGallery: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    @State private var editor: WidgetEditorRoute?

    private var event: CountEvent? {
        store.events.first(where: { $0.id == eventID })
    }
    private var presets: [WidgetPreset] {
        store.widgetPresets.filter { $0.eventID == eventID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let event {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Оформления для «\(event.title)»")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .center, spacing: 14) {
                            WidgetCardPreview(event: event, image: nil, wide: false)
                                .frame(width: 155, height: 155)
                            Button {
                                editor = .create
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 27, weight: .medium))
                                    Text("Добавить")
                                        .font(.subheadline.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 155)
                                .background(Color(uiColor: .secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 24))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("addWidgetPreset")
                        }
                        Text("Мои виджеты")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                        if presets.isEmpty {
                            Text("Создай собственное оформление. Его можно будет выбрать при добавлении виджета на экран iPhone.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(presets) { preset in
                            Button {
                                editor = .edit(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(preset.title)
                                                .font(.headline)
                                            Text(preset.size.title)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                    let appearance = preset.applying(to: event)
                                    WidgetCardPreview(event: appearance, image: nil,
                                                      wide: preset.size != .small,
                                                      large: preset.size == .large)
                                        .frame(height: preset.size == .large ? 295 : 155)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Как добавить на iPhone", systemImage: "info.circle")
                                .font(.headline)
                            Text("Удерживай домашний экран → Добавить виджет → Дни → выбери размер. Затем удерживай виджет → Изменить виджет → Оформление и выбери сохранённый вариант. iOS не разрешает приложению размещать виджеты автоматически.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(20)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Виджеты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(item: $editor) { route in
                if let event {
                    WidgetPresetEditor(event: event, existing: route.preset)
                        .environmentObject(store)
                }
            }
        }
    }
}

struct WidgetPresetEditor: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss

    let event: CountEvent
    let existing: WidgetPreset?
    @State private var draft: WidgetPreset
    @State private var chosenColor = Color.white
    @State private var chosenBackground = Color.white
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var pendingPhoto: UIImage?
    @State private var photoError = false

    init(event: CountEvent, existing: WidgetPreset? = nil) {
        self.event = event
        self.existing = existing
        _draft = State(initialValue: existing ?? WidgetPreset(event: event))
    }

    private var renderedEvent: CountEvent {
        draft.applying(to: event)
    }

    private var photo: UIImage? {
        pendingPhoto ?? EventPhotoStore.image(named: renderedEvent.photoFilename)
    }

    private var typeWeight: Binding<Double> {
        let weights = CardThickness.allCases
        return Binding(
            get: { Double(weights.firstIndex(of: draft.style.thickness) ?? 4) },
            set: { value in
                draft.style.thickness = weights[min(max(Int(value.rounded()), 0), weights.count - 1)]
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Виджет") {
                    TextField("Название оформления", text: $draft.title)
                        .onChange(of: draft.title) { _, text in
                            if text.count > 70 { draft.title = String(text.prefix(70)) }
                        }
                    Picker("Размер", selection: $draft.size) {
                        ForEach(WidgetPresetSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .onChange(of: draft.size) { _, size in
                        if size == .small {
                            let unit = draft.units.selected.first ?? .days
                            draft.units = .fromLegacy(unit)
                        }
                    }
                    WidgetCardPreview(event: renderedEvent, image: photo,
                                      wide: draft.size != .small, large: draft.size == .large)
                        .frame(height: draft.size == .large ? 295 : 165)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                Section("Что показывать") {
                    if draft.size != .small {
                        Toggle("Автоматически", isOn: $draft.units.automatic)
                    }
                    if !draft.units.automatic || draft.size == .small {
                        unitToggle(.days, label: "Дни")
                        unitToggle(.hours, label: "Часы")
                        unitToggle(.minutes, label: "Минуты")
                    }
                    if draft.size == .small {
                        Text("Малый виджет показывает один показатель.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Шрифт") {
                    Picker("Стиль", selection: $draft.style.typeface) {
                        ForEach(CardTypeface.allCases) { face in
                            Text(face.title).tag(face)
                        }
                    }
                    HStack {
                        Text("Размер")
                        Slider(value: $draft.style.scale, in: 0.7...1.6)
                        Text("\(Int((draft.style.scale * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                    }
                    HStack {
                        Text("Толщина")
                        Slider(value: typeWeight, in: 0...5, step: 1)
                    }
                    Picker("Цвет текста", selection: $draft.style.textColorHex) {
                        ForEach(CardColorPalette.swatches, id: \.self) { hex in
                            Text(hex).tag(hex)
                        }
                    }
                    ColorPicker("Свой цвет текста", selection: $chosenColor, supportsOpacity: false)
                        .onChange(of: chosenColor) { _, color in
                            draft.style.textColorHex = color.rgbHex
                        }
                }
                Section("Фон") {
                    Toggle("Использовать фото события", isOn: $draft.useEventPhoto)
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        Label("Своё фото виджета", systemImage: "photo")
                    }
                    if draft.photoFilename != nil || pendingPhoto != nil {
                        Button("Убрать собственное фото", role: .destructive) {
                            draft.photoFilename = nil
                            pendingPhoto = nil
                            draft.useEventPhoto = false
                        }
                    }
                    Picker("Градиент", selection: $draft.palette) {
                        ForEach(EventPalette.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    ColorPicker("Свой цвет фона", selection: $chosenBackground, supportsOpacity: false)
                        .onChange(of: chosenBackground) { _, color in
                            draft.backgroundColorHex = color.rgbHex
                        }
                    Button("Вернуть градиент") { draft.backgroundColorHex = nil }
                    if photo != nil {
                        HStack {
                            Text("Затемнение")
                            Slider(value: $draft.maskOpacity, in: 0...0.9)
                        }
                    }
                }
                if existing != nil {
                    Section {
                        Button("Удалить оформление", role: .destructive) {
                            if let existing { store.removePreset(existing) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Новый виджет" : "Оформление виджета")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .bold()
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                chosenColor = Color(rgbHex: draft.style.textColorHex)
                chosenBackground = Color(rgbHex: draft.backgroundColorHex ?? "F0E3D1")
            }
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        photoError = true
                        return
                    }
                    pendingPhoto = image
                    draft.useEventPhoto = false
                }
            }
            .alert("Не удалось сохранить фотографию", isPresented: $photoError) {
                Button("ОК", role: .cancel) {}
            }
        }
    }

    private func unitToggle(_ unit: CountUnit, label: String) -> some View {
        Toggle(label, isOn: Binding(
            get: {
                switch unit {
                case .days: draft.units.days
                case .hours: draft.units.hours
                case .minutes: draft.units.minutes
                case .automatic: false
                }
            },
            set: { enabled in
                if draft.size == .small {
                    draft.units = .fromLegacy(unit)
                } else {
                    draft.units.select(unit, enabled: enabled)
                }
            }
        ))
    }

    private func save() {
        if let pendingPhoto {
            guard let filename = EventPhotoStore.save(pendingPhoto, for: draft.id) else {
                photoError = true
                return
            }
            draft.photoFilename = filename
        }
        draft.title = String(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(70))
        if draft.size == .small {
            draft.units = .fromLegacy(draft.units.selected.first ?? .days)
        }
        if existing == nil { store.addPreset(draft) } else { store.updatePreset(draft) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
