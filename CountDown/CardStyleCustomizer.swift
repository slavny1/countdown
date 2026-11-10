import SwiftUI
import PhotosUI
import UIKit

/// Live editor that never nests a changing Form inside a segmented picker.
struct CardStyleCustomizer: View {
    @Binding var style: CardStyle
    @Binding var palette: EventPalette
    @Binding var backgroundColorHex: String?
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
    @State private var section: SectionChoice = .font
    @State private var customTextColor = Color.white
    @State private var customBackgroundColor = Color.white
    @State private var customMaskColor = Color.black
    @State private var showsCustomBackground = false
    @State private var showsCustomMask = false
    @State private var loadError = false

    private enum SectionChoice: String, CaseIterable, Identifiable {
        case font = "Шрифт", color = "Цвет", background = "Фон"
        var id: String { rawValue }
    }

    private let maskSwatches = ["141414", "142957", "F0E3D1", "FFFFFF"]

    private var currentPhoto: UIImage? {
        if removePhoto { return nil }
        return pendingImage ?? EventPhotoStore.image(named: previewEvent.photoFilename)
    }

    private var liveEvent: CountEvent {
        var copy = previewEvent
        copy.style = style
        copy.palette = palette
        copy.backgroundColorHex = backgroundColorHex
        copy.maskColorHex = maskColorHex
        copy.maskOpacity = maskOpacity
        copy.photoZoom = photoZoom
        copy.photoFocusX = photoFocusX
        copy.photoFocusY = photoFocusY
        return copy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading("Карточка")
                        EventCard(event: liveEvent, now: .now, previewImage: currentPhoto)
                            .frame(height: 176)
                        HStack {
                            sectionHeading("Виджеты")
                            Spacer()
                            Text("Предпросмотр")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(alignment: .top, spacing: 14) {
                            WidgetCardPreview(event: liveEvent, image: currentPhoto, wide: false)
                                .frame(width: 144, height: 144)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Ближайшая круглая дата")
                                    .font(.caption.weight(.medium))
                                if let milestone = EventMilestones.next(for: liveEvent) {
                                    Text(milestone.title)
                                        .font(.system(size: 24, weight: .bold, design: .serif))
                                    Text(milestone.date.formatted(.dateTime.day().month(.abbreviated).year()))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Нет ближайшей даты")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                        }
                        WidgetCardPreview(event: liveEvent, image: currentPhoto, wide: true)
                            .frame(height: 156)
                    }
                    .animation(.easeInOut(duration: 0.15), value: style)

                    HStack(spacing: 8) {
                        ForEach(SectionChoice.allCases) { choice in
                            Button {
                                section = choice
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text(choice.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(section == choice ? Color.white : Color.primary)
                                    .background(section == choice ? Color.accentColor :
                                                Color(uiColor: .secondarySystemGroupedBackground),
                                                in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(section == choice ? [.isSelected] : [])
                        }
                    }
                    .accessibilityIdentifier("styleSections")

                    Group {
                        switch section {
                        case .font: fontControls
                        case .color: colorControls
                        case .background: backgroundControls
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
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
                customTextColor = Color(rgbHex: style.textColorHex)
                customMaskColor = Color(rgbHex: maskColorHex)
                customBackgroundColor = Color(rgbHex: backgroundColorHex ?? "F0E3D1")
            }
            .onChange(of: selectedPhoto) { _, selection in
                guard let selection else { return }
                Task {
                    guard let data = try? await selection.loadTransferable(type: Data.self),
                          let photo = UIImage(data: data) else {
                        loadError = true
                        return
                    }
                    pendingImage = photo
                    removePhoto = false
                }
            }
            .alert("Не удалось открыть фотографию", isPresented: $loadError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title).font(.system(size: 21, weight: .bold, design: .serif))
    }

    private var fontControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading("Шрифт числа и названия")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CardTypeface.allCases) { choice in
                    Button {
                        style.typeface = choice
                    } label: {
                        VStack(spacing: 6) {
                            Text("123")
                                .font(.system(size: 37, weight: style.thickness.fontWeight,
                                              design: choice.fontDesign))
                            Text(choice.title).font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundStyle(style.typeface == choice ? Color.accentColor : Color.primary)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(style.typeface == choice ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text("Размер цифр")
                Slider(value: $style.scale, in: 0.7...1.6)
                    .accessibilityIdentifier("fontScale")
                Text("\(Int((style.scale * 100).rounded()))%")
                    .monospacedDigit()
                    .font(.caption)
                    .frame(width: 48)
            }
            HStack {
                Text("Толщина")
                Slider(value: thicknessValue, in: 0...5, step: 1)
                    .accessibilityIdentifier("fontWeight")
                Text(style.thickness.title)
                    .font(.caption)
                    .frame(width: 90, alignment: .trailing)
            }
            Button("Сбросить шрифт") {
                style.typeface = .editorial
                style.scale = 1
                style.thickness = .bold
            }
            .font(.subheadline)
        }
    }

    private var thicknessValue: Binding<Double> {
        let cases = CardThickness.allCases
        return Binding(
            get: { Double(cases.firstIndex(of: style.thickness) ?? 4) },
            set: { newValue in
                let index = min(max(Int(newValue.rounded()), 0), cases.count - 1)
                style.thickness = cases[index]
            }
        )
    }

    private var colorControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Цвет текста")
            swatches(CardColorPalette.swatches, selected: style.textColorHex) { hex in
                style.textColorHex = hex
                customTextColor = Color(rgbHex: hex)
            }
            ColorPicker("Другой цвет", selection: $customTextColor, supportsOpacity: false)
                .onChange(of: customTextColor) { _, value in style.textColorHex = value.rgbHex }
        }
    }

    private var backgroundControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Фотография")
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(currentPhoto == nil ? "Добавить фото" : "Заменить фото", systemImage: "photo")
            }
            .buttonStyle(.bordered)
            if currentPhoto != nil {
                Button("Убрать фото", role: .destructive) {
                    pendingImage = nil
                    selectedPhoto = nil
                    removePhoto = true
                }
                .font(.subheadline)
                HStack {
                    Text("Масштаб")
                    Slider(value: $photoZoom, in: 1...2.5)
                }
                HStack {
                    Text("Сдвиг X")
                    Slider(value: $photoFocusX, in: 0...1)
                }
                HStack {
                    Text("Сдвиг Y")
                    Slider(value: $photoFocusY, in: 0...1)
                }
                sectionHeading("Цвет маски")
                HStack(spacing: 12) {
                    ForEach(maskSwatches, id: \.self) { hex in
                        circleColor(hex, selected: maskColorHex == hex) {
                            maskColorHex = hex
                            customMaskColor = Color(rgbHex: hex)
                        }
                    }
                    Button {
                        showsCustomMask.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 43, height: 43)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Свой цвет маски")
                }
                if showsCustomMask {
                    ColorPicker("Свой цвет маски", selection: $customMaskColor, supportsOpacity: false)
                        .onChange(of: customMaskColor) { _, color in maskColorHex = color.rgbHex }
                }
                HStack {
                    Text("Непрозрачность")
                    Slider(value: $maskOpacity, in: 0...0.9)
                    Text("\(Int((maskOpacity * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                }
            } else {
                sectionHeading("Фон без фото")
                HStack(spacing: 9) {
                    ForEach(EventPalette.allCases) { value in
                        Button {
                            palette = value
                            backgroundColorHex = nil
                        } label: {
                            Circle()
                                .fill(value.gradient)
                                .frame(width: 39, height: 39)
                                .overlay {
                                    if palette == value && backgroundColorHex == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(value.title)
                    }
                    Button { showsCustomBackground.toggle() } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 39, height: 39)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Свой цвет фона")
                }
                if showsCustomBackground || backgroundColorHex != nil {
                    ColorPicker("Цвет фона", selection: $customBackgroundColor, supportsOpacity: false)
                        .onChange(of: customBackgroundColor) { _, color in
                            backgroundColorHex = color.rgbHex
                        }
                }
            }
        }
    }

    private func swatches(_ colors: [String], selected: String,
                          onSelect: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            ForEach(colors, id: \.self) { hex in
                circleColor(hex, selected: selected == hex) { onSelect(hex) }
            }
        }
    }

    private func circleColor(_ hex: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color(rgbHex: hex))
                .frame(width: 43, height: 43)
                .overlay(Circle().strokeBorder(.gray.opacity(0.3)))
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(hex == "141414" || hex == "142957" || hex == "1B2029" ? .white : .black)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Цвет \(hex)")
    }
}

/// Same layout as the Home Screen widget. This is a preview, not an actual WidgetKit snapshot.
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
                            .font(.system(size: 21, weight: event.style.thickness.fontWeight,
                                          design: event.style.typeface.fontDesign))
                            .lineLimit(2)
                        Text(event.date.displayLabel)
                            .font(.caption.weight(.medium))
                            .opacity(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(count.number, format: .number)
                            .font(.system(size: 76 * CGFloat(min(max(event.style.scale, 0.7), 1.6)),
                                          weight: event.style.thickness.fontWeight,
                                          design: event.style.typeface.fontDesign))
                            .monospacedDigit()
                            .minimumScaleFactor(0.35)
                            .lineLimit(1)
                        Text(count.unitLabel)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(14)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text(count.direction.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                    Spacer(minLength: 0)
                    Text(count.number, format: .number)
                        .font(.system(size: 74 * CGFloat(min(max(event.style.scale, 0.7), 1.6)),
                                      weight: event.style.thickness.fontWeight,
                                      design: event.style.typeface.fontDesign))
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                        .monospacedDigit()
                    Text(count.unitLabel).font(.caption.weight(.semibold))
                    Text(event.title)
                        .font(.system(size: 15, weight: event.style.thickness.fontWeight,
                                      design: event.style.typeface.fontDesign))
                        .lineLimit(1)
                }
                .padding(13)
            }
        }
        .foregroundStyle(event.style.textColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { EventBackground(event: event, previewImage: image) }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
