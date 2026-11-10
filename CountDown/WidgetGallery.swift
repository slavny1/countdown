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

struct WidgetGallery: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    @State private var editor: WidgetEditorRoute?

    private var event: CountEvent? { store.events.first { $0.id == eventID } }
    private var presets: [WidgetPreset] { store.widgetPresets.filter { $0.eventID == eventID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let event {
                    VStack(alignment: .leading, spacing: 17) {
                        Text("Оформления для «\(event.title)»")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        HStack(spacing: 14) {
                            WidgetCardPreview(event: event,
                                              image: EventPhotoStore.image(named: event.photoFilename),
                                              wide: false)
                                .frame(width: 155, height: 155)
                            Button {
                                editor = .create
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus").font(.title.weight(.medium))
                                    Text("Добавить").font(.subheadline.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 155)
                                .background(Color(uiColor: .secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 24))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("addWidgetPreset")
                        }

                        Text("Мои виджеты").font(.system(size: 22, weight: .bold, design: .serif))
                        if presets.isEmpty {
                            Text("Нажми +, выбери размер и оформление. Созданный вариант можно выбрать при добавлении виджета на экран iPhone.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        ForEach(presets) { preset in
                            Button {
                                editor = .edit(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(preset.title).font(.headline)
                                        Spacer()
                                        Image(systemName: "slider.horizontal.3")
                                    }
                                    .foregroundStyle(.primary)
                                    presetPreview(preset, event: event)
                                }
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 22))
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Чтобы добавить на экран: удерживай домашний экран → Добавить виджет → Дни. Выбери размер, затем в «Изменить виджет» укажи созданное оформление. iOS не позволяет добавить его на экран автоматически.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    .padding(20)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Виджеты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
            .sheet(item: $editor) { route in
                if let event {
                    WidgetPresetEditor(event: event, existing: route.preset).environmentObject(store)
                }
            }
        }
    }

    private func presetPreview(_ preset: WidgetPreset, event: CountEvent) -> some View {
        let size = preset.size
        let picture = EventPhotoStore.image(named: preset.applying(to: event).photoFilename)
        return GeometryReader { geometry in
            let width: CGFloat = size == .small ? 156 : 325
            let height: CGFloat = size == .large ? 296 : 156
            HStack {
                Spacer(minLength: 0)
                WidgetCardPreview(event: preset.applying(to: event), image: picture,
                                  wide: size != .small, large: size == .large)
                    .frame(width: min(geometry.size.width, width), height: height)
                Spacer(minLength: 0)
            }
        }
        .frame(height: size == .large ? 296 : 156)
    }
}

private enum WidgetColorTarget: String, Identifiable {
    case text, background, mask
    var id: String { rawValue }
}

struct WidgetPresetEditor: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss
    let event: CountEvent
    let existing: WidgetPreset?

    @State private var draft: WidgetPreset
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var pendingPhoto: UIImage?
    @State private var photoError = false
    @State private var customColor = Color.white
    @State private var editingColor: WidgetColorTarget?
    @State private var textColors: [String] = []
    @State private var backgroundColors: [String] = []
    @State private var maskColors: [String] = []
    @State private var colorEdited = false

    private let basicText = ["FFFFFF", "1B2029", "F6CF59", "C8E9FF"]
    private let basicBackground = ["F0E3D1", "1B2029", "5373B9", "E6A681"]
    private let basicMask = ["141414", "142957", "F0E3D1", "FFFFFF"]

    init(event: CountEvent, existing: WidgetPreset? = nil) {
        self.event = event
        self.existing = existing
        _draft = State(initialValue: existing ?? WidgetPreset(event: event))
    }

    private var renderedEvent: CountEvent { draft.applying(to: event) }
    private var photo: UIImage? {
        pendingPhoto ?? EventPhotoStore.image(named: renderedEvent.photoFilename)
    }

    private var previewWidth: CGFloat { draft.size == .small ? 160 : 325 }
    private var previewHeight: CGFloat { draft.size == .large ? 310 : 160 }

    private var fontWeight: Binding<Double> {
        let weights = CardThickness.allCases
        return Binding(
            get: { Double(weights.firstIndex(of: draft.style.thickness) ?? 4) },
            set: { draft.style.thickness = weights[min(max(Int($0.rounded()), 0), weights.count - 1)] }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        ForEach(WidgetPresetSize.allCases) { size in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    draft.size = size
                                    if size == .small {
                                        draft.units = .fromLegacy(draft.units.selected.first ?? .days)
                                    }
                                }
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: size == .small ? "square" :
                                          size == .medium ? "rectangle" : "rectangle.portrait")
                                        .font(.title3)
                                    Text(size.title)
                                        .font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 59)
                                .foregroundStyle(draft.size == size ? Color.white : Color.primary)
                                .background(draft.size == size ? Color.accentColor :
                                            Color(uiColor: .tertiarySystemFill),
                                            in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    GeometryReader { geometry in
                        HStack {
                            Spacer(minLength: 0)
                            WidgetCardPreview(event: renderedEvent, image: photo,
                                              wide: draft.size != .small, large: draft.size == .large)
                                .frame(width: min(geometry.size.width, previewWidth),
                                       height: previewHeight)
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: previewHeight)
                    .animation(.easeInOut(duration: 0.25), value: draft.size)
                } header: {
                    Text("Размер и виджет")
                }

                Section {
                    if draft.size != .small {
                        Toggle("Автоматически", isOn: $draft.units.automatic)
                    }
                    if !draft.units.automatic || draft.size == .small {
                        unitToggle(.days, label: "Дни")
                        unitToggle(.hours, label: "Часы")
                        unitToggle(.minutes, label: "Минуты")
                    }
                } header: {
                    Text("Что показывать")
                } footer: {
                    if draft.size == .small {
                        Text("Малый виджет отображает только один показатель.")
                    } else {
                        Text("Средний и большой могут показывать дни, часы и минуты одновременно.")
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
                            .accessibilityIdentifier("widgetFontScale")
                        Text("\(Int((draft.style.scale * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                    }
                    HStack {
                        Text("Толщина")
                        Slider(value: fontWeight, in: 0...5, step: 1)
                    }
                    colorRow(basics: basicText, custom: textColors,
                             selected: draft.style.textColorHex, target: .text)
                }

                Section("Фон") {
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        Label(photo == nil ? "Выбрать фото" : "Заменить фото", systemImage: "photo")
                    }
                    if photo != nil {
                        Button(role: .destructive) {
                            draft.useEventPhoto = false
                            draft.photoFilename = nil
                            pickedPhoto = nil
                            pendingPhoto = nil
                        } label: {
                            Label("Удалить фото", systemImage: "trash")
                        }
                        colorRow(basics: basicMask, custom: maskColors,
                                 selected: draft.maskColorHex, target: .mask)
                        HStack {
                            Text("Непрозрачность")
                            Slider(value: $draft.maskOpacity, in: 0...0.9)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(EventPalette.allCases) { choice in
                                    Button {
                                        draft.palette = choice
                                        draft.backgroundColorHex = nil
                                        chooseContrast()
                                    } label: {
                                        Circle().fill(choice.gradient)
                                            .frame(width: 43, height: 43)
                                            .overlay {
                                                if draft.palette == choice && draft.backgroundColorHex == nil {
                                                    Image(systemName: "checkmark")
                                                        .foregroundStyle(choice == .sand ? .black : .white)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(choice.title)
                                }
                            }
                        }
                        colorRow(basics: basicBackground, custom: backgroundColors,
                                 selected: draft.backgroundColorHex ?? "", target: .background)
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
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.bold()
                }
            }
            .onAppear {
                textColors = UserDefaults.standard.stringArray(forKey: "days.customTextColors") ?? []
                backgroundColors = UserDefaults.standard.stringArray(forKey: "days.customBackgrounds") ?? []
                maskColors = UserDefaults.standard.stringArray(forKey: "days.customMasks") ?? []
                if existing == nil { chooseContrast() }
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
                    if !colorEdited { draft.style.textColorHex = "FFFFFF" }
                }
            }
            .alert("Не удалось сохранить фотографию", isPresented: $photoError) {
                Button("ОК", role: .cancel) {}
            }
            .sheet(item: $editingColor) { target in
                NavigationStack {
                    Form {
                        ColorPicker("Свой цвет", selection: $customColor, supportsOpacity: false)
                    }
                    .navigationTitle("Добавить цвет")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") { editingColor = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Добавить") {
                                apply(color: customColor.rgbHex, to: target, saveSwatch: true)
                                editingColor = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
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
                if draft.size == .small { draft.units = .fromLegacy(unit) }
                else { draft.units.select(unit, enabled: enabled) }
            }
        ))
    }

    private func colorRow(basics: [String], custom: [String],
                          selected: String, target: WidgetColorTarget) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 11) {
                ForEach(basics + custom.filter { !basics.contains($0) }, id: \.self) { hex in
                    Button {
                        apply(color: hex, to: target, saveSwatch: false)
                    } label: {
                        Circle().fill(Color(rgbHex: hex))
                            .frame(width: 43, height: 43)
                            .overlay(Circle().strokeBorder(.gray.opacity(0.3)))
                            .overlay {
                                if selected == hex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(hex == "1B2029" || hex == "141414" ||
                                                         hex == "142957" ? .white : .black)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Цвет \(hex)")
                }
                Button {
                    let color: String
                    switch target {
                    case .text: color = draft.style.textColorHex
                    case .background: color = draft.backgroundColorHex ?? "FFFFFF"
                    case .mask: color = draft.maskColorHex
                    }
                    customColor = Color(rgbHex: color)
                    editingColor = target
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

    private func apply(color: String, to target: WidgetColorTarget, saveSwatch: Bool) {
        switch target {
        case .text:
            draft.style.textColorHex = color
            colorEdited = true
            if saveSwatch && !textColors.contains(color) && !basicText.contains(color) {
                textColors.append(color)
                UserDefaults.standard.set(textColors, forKey: "days.customTextColors")
            }
        case .background:
            draft.backgroundColorHex = color
            chooseContrast()
            if saveSwatch && !backgroundColors.contains(color) && !basicBackground.contains(color) {
                backgroundColors.append(color)
                UserDefaults.standard.set(backgroundColors, forKey: "days.customBackgrounds")
            }
        case .mask:
            draft.maskColorHex = color
            if !colorEdited { draft.style.textColorHex = color == "FFFFFF" || color == "F0E3D1" ? "1B2029" : "FFFFFF" }
            if saveSwatch && !maskColors.contains(color) && !basicMask.contains(color) {
                maskColors.append(color)
                UserDefaults.standard.set(maskColors, forKey: "days.customMasks")
            }
        }
    }

    private func chooseContrast() {
        guard !colorEdited else { return }
        if renderedEvent.photoFilename != nil || pendingPhoto != nil {
            draft.style.textColorHex = "FFFFFF"
            return
        }
        if let hex = draft.backgroundColorHex, let code = UInt64(hex, radix: 16) {
            let r = Double((code >> 16) & 0xff) / 255
            let g = Double((code >> 8) & 0xff) / 255
            let b = Double(code & 0xff) / 255
            draft.style.textColorHex = (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.56
                ? "1B2029" : "FFFFFF"
        } else {
            draft.style.textColorHex = draft.palette == .sand ? "1B2029" : "FFFFFF"
        }
    }

    private func save() {
        if let pendingPhoto {
            guard let name = EventPhotoStore.save(pendingPhoto, for: draft.id) else {
                photoError = true
                return
            }
            draft.photoFilename = name
        }
        if draft.size == .small {
            draft.units = .fromLegacy(draft.units.selected.first ?? .days)
        }
        if existing == nil {
            let matching = store.widgetPresets.filter {
                $0.eventID == event.id && $0.size == draft.size
            }.count
            draft.title = matching == 0 ? "\(draft.size.title) · \(event.title)"
                : "\(draft.size.title) · \(event.title) · \(matching + 1)"
            store.addPreset(draft)
        } else {
            store.updatePreset(draft)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
