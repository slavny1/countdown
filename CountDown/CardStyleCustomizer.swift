import SwiftUI
import PhotosUI
import UIKit

private enum PreviewKind: String, CaseIterable, Identifiable {
    case card = "Карточка"
    case small = "Виджет"
    case medium = "Широкий"
    var id: String { rawValue }
}

/// One live editor for photos, typography and both Home Screen widget sizes.
/// The preview uses pending images as well as images already saved in the App Group.
struct CardStyleCustomizer: View {
    @Binding var style: CardStyle
    @Binding var palette: EventPalette
    @Binding var maskColorHex: String
    @Binding var maskOpacity: Double
    @Binding var photoZoom: Double
    @Binding var photoFocusX: Double
    @Binding var photoFocusY: Double
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var pendingImage: UIImage?
    @Binding var removePhoto: Bool

    let previewEvent: CountEvent
    @Environment(\.dismiss) private var dismiss

    @State private var tab: EditorTab = .font
    @State private var preview: PreviewKind = .card
    @State private var chosenTextColor: Color = .white
    @State private var chosenMaskColor: Color = .black
    @State private var photoError = false

    private enum EditorTab: String, CaseIterable, Identifiable {
        case font = "Шрифт"
        case color = "Цвет"
        case background = "Фон"
        case layout = "Макет"
        var id: String { rawValue }
    }

    private var currentPhoto: UIImage? {
        if removePhoto { return nil }
        return pendingImage ?? EventPhotoStore.image(named: previewEvent.photoFilename)
    }

    private var liveEvent: CountEvent {
        var event = previewEvent
        event.style = style
        event.palette = palette
        event.maskColorHex = maskColorHex
        event.maskOpacity = maskOpacity
        event.photoZoom = photoZoom
        event.photoFocusX = photoFocusX
        event.photoFocusY = photoFocusY
        return event
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Picker("Предпросмотр", selection: $preview) {
                        ForEach(PreviewKind.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 18)

                    Group {
                        switch preview {
                        case .card:
                            EventCard(event: liveEvent, now: .now, previewImage: currentPhoto)
                                .frame(height: 176)
                        case .small:
                            HStack {
                                Spacer(minLength: 0)
                                WidgetCardPreview(event: liveEvent, image: currentPhoto, wide: false)
                                    .frame(width: 170, height: 170)
                                Spacer(minLength: 0)
                            }
                        case .medium:
                            WidgetCardPreview(event: liveEvent, image: currentPhoto, wide: true)
                                .frame(height: 170)
                        }
                    }
                    .padding(.horizontal, 18)
                    .animation(.easeInOut(duration: 0.2), value: preview)
                    .animation(.easeInOut(duration: 0.15), value: style)
                }
                .padding(.top, 12)
                .padding(.bottom, 14)

                Picker("Инструменты", selection: $tab) {
                    ForEach(EditorTab.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Form {
                    switch tab {
                    case .font:
                        Section("Шрифт цифр") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(CardTypeface.allCases) { typeface in
                                    Button {
                                        style.typeface = typeface
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    } label: {
                                        VStack(spacing: 6) {
                                            Text("123")
                                                .font(.system(size: 36, weight: style.thickness.fontWeight,
                                                              design: typeface.fontDesign))
                                                .monospacedDigit()
                                            Text(typeface.title).font(.caption)
                                        }
                                        .foregroundStyle(style.typeface == typeface ? Color.accentColor : Color.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                                    in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14)
                                            .stroke(style.typeface == typeface ? Color.accentColor : .clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        Section("Начертание и размер") {
                            Picker("Толщина", selection: $style.thickness) {
                                ForEach(CardThickness.allCases) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                            HStack {
                                Text("Размер")
                                Slider(value: $style.scale, in: 0.75...1.45, step: 0.05)
                                Text("\(Int((style.scale * 100).rounded()))%")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 45, alignment: .trailing)
                            }
                        }

                    case .color:
                        Section("Цвет текста") {
                            colorSwatches(selected: $style.textColorHex) { hex in
                                chosenTextColor = Color(rgbHex: hex)
                            }
                            ColorPicker("Другой цвет", selection: $chosenTextColor, supportsOpacity: false)
                                .onChange(of: chosenTextColor) { _, value in
                                    style.textColorHex = value.rgbHex
                                }
                        }

                    case .background:
                        Section("Фотография") {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label(currentPhoto == nil ? "Добавить фотографию" : "Изменить фотографию",
                                      systemImage: "photo.on.rectangle.angled")
                            }
                            if currentPhoto != nil {
                                Button(role: .destructive) {
                                    removePhoto = true
                                    pendingImage = nil
                                    selectedPhoto = nil
                                } label: {
                                    Label("Убрать фотографию", systemImage: "trash")
                                }
                            }
                        }
                        Section("Фон без фото") {
                            HStack(spacing: 12) {
                                ForEach(EventPalette.allCases) { value in
                                    Button {
                                        palette = value
                                    } label: {
                                        Circle()
                                            .fill(value.gradient)
                                            .frame(width: 46, height: 46)
                                            .overlay {
                                                if palette == value {
                                                    Image(systemName: "checkmark")
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(value.title)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        Section("Цвет маски поверх фото") {
                            colorSwatches(selected: $maskColorHex) { hex in
                                chosenMaskColor = Color(rgbHex: hex)
                            }
                            ColorPicker("Другой цвет маски", selection: $chosenMaskColor,
                                        supportsOpacity: false)
                                .onChange(of: chosenMaskColor) { _, value in
                                    maskColorHex = value.rgbHex
                                }
                            HStack {
                                Text("Непрозрачность")
                                Slider(value: $maskOpacity, in: 0...0.9, step: 0.05)
                                Text("\(Int((maskOpacity * 100).rounded()))%")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 43, alignment: .trailing)
                            }
                            .disabled(currentPhoto == nil)
                            if currentPhoto != nil {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Кадрирование")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        Text("Масштаб")
                                        Slider(value: $photoZoom, in: 1...2.5, step: 0.05)
                                        Text(String(format: "%.1f×", photoZoom))
                                            .font(.caption.monospacedDigit())
                                            .frame(width: 40)
                                    }
                                    HStack {
                                        Text("По горизонтали")
                                        Slider(value: $photoFocusX, in: 0...1)
                                    }
                                    HStack {
                                        Text("По вертикали")
                                        Slider(value: $photoFocusY, in: 0...1)
                                    }
                                    Button("Центрировать фотографию") {
                                        photoFocusX = 0.5
                                        photoFocusY = 0.5
                                        photoZoom = 1
                                    }
                                }
                            }
                        }

                    case .layout:
                        Section("Выравнивание числа") {
                            Picker("Позиция", selection: $style.alignment) {
                                ForEach(CardAlignment.allCases) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Section("Подпись рядом с числом") {
                            Picker("Размещение", selection: $style.unitPlacement) {
                                ForEach(CardUnitPlacement.allCases) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Section {
                            Button("Сбросить стиль карточки") {
                                style = CardStyle()
                                chosenTextColor = .white
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Оформление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear {
                chosenTextColor = Color(rgbHex: style.textColorHex)
                chosenMaskColor = Color(rgbHex: maskColorHex)
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self),
                              let photo = UIImage(data: data) else {
                            photoError = true
                            return
                        }
                        pendingImage = photo
                        removePhoto = false
                    } catch {
                        photoError = true
                    }
                }
            }
            .alert("Не удалось загрузить фото", isPresented: $photoError) {
                Button("ОК", role: .cancel) {}
            }
        }
    }

    private func colorSwatches(selected: Binding<String>, onSelect: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            ForEach(CardColorPalette.swatches, id: \.self) { hex in
                Button {
                    selected.wrappedValue = hex
                    onSelect(hex)
                } label: {
                    Circle()
                        .fill(Color(rgbHex: hex))
                        .frame(width: 43, height: 43)
                        .overlay(Circle().stroke(.black.opacity(0.15)))
                        .overlay {
                            if selected.wrappedValue == hex {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(hex == "1B2029" ? .white : .black)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Цвет \(hex)")
            }
        }
        .padding(.vertical, 6)
    }
}

/// Approximation of actual WidgetKit content, with the same compositions and styles.
struct WidgetCardPreview: View {
    let event: CountEvent
    let image: UIImage?
    let wide: Bool

    private var count: CountReading { DayCount.reading(for: event) }

    var body: some View {
        Group {
            if wide {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(count.direction.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                        Text(event.title)
                            .font(.system(size: 21, weight: .bold, design: event.style.typeface.fontDesign))
                            .lineLimit(2)
                        Text(event.date.date().formatted(.dateTime.day().month(.wide)))
                            .font(.caption.weight(.medium))
                            .opacity(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(count.number, format: .number)
                            .font(.system(size: 76 * CGFloat(min(max(event.style.scale, 0.75), 1.45)),
                                          weight: event.style.thickness.fontWeight,
                                          design: event.style.typeface.fontDesign))
                            .monospacedDigit()
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text(count.unitLabel)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(18)
            } else {
                VStack(alignment: event.style.horizontalAlignment, spacing: 5) {
                    Text(count.direction.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1)
                    Spacer(minLength: 0)
                    Text(count.number, format: .number)
                        .font(.system(size: 74 * CGFloat(min(max(event.style.scale, 0.75), 1.45)),
                                      weight: event.style.thickness.fontWeight,
                                      design: event.style.typeface.fontDesign))
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                        .monospacedDigit()
                    Text(count.unitLabel)
                        .font(.caption.weight(.semibold))
                    Text(event.title)
                        .font(.system(size: 15, weight: .bold, design: event.style.typeface.fontDesign))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: event.style.swiftUIAlignment)
                .padding(15)
            }
        }
        .foregroundStyle(event.style.textColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { EventBackground(event: event, previewImage: image) }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
