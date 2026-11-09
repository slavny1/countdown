import SwiftUI
import UIKit

/// A focused, live card editor inspired by the iOS lock-screen clock customization.
struct CardStyleCustomizer: View {
    @Binding var style: CardStyle
    let previewEvent: CountEvent
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: EditorTab = .font
    @State private var customColor: Color = .white

    private enum EditorTab: String, CaseIterable, Identifiable {
        case font = "Шрифт"
        case color = "Цвет"
        case layout = "Макет"
        var id: String { rawValue }
    }

    private let swatches = ["FFFFFF", "F0E3D1", "1B2029", "F6CF59", "C8E9FF", "E8C4F0", "B9EDC6", "FFB8A7"]

    private var liveEvent: CountEvent {
        var event = previewEvent
        event.style = style
        return event
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 13) {
                    Text("ПРЕДПРОСМОТР")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.9)
                        .foregroundStyle(.secondary)
                    EventCard(event: liveEvent, now: .now)
                        .frame(maxWidth: 430)
                        .padding(.horizontal, 18)
                        .animation(.easeInOut(duration: 0.18), value: style)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)

                Picker("Настройки", selection: $selectedTab) {
                    ForEach(EditorTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                Form {
                    switch selectedTab {
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
                                                .font(.system(size: 38, weight: style.thickness.fontWeight,
                                                              design: typeface.fontDesign))
                                                .monospacedDigit()
                                            Text(typeface.title)
                                                .font(.caption)
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
                                    .accessibilityAddTraits(style.typeface == typeface ? [.isSelected] : [])
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        Section("Толщина") {
                            Picker("Начертание", selection: $style.thickness) {
                                ForEach(CardThickness.allCases) { weight in
                                    Text(weight.title).tag(weight)
                                }
                            }
                            .pickerStyle(.menu)
                            HStack {
                                Text("Размер")
                                Slider(value: $style.scale, in: 0.75...1.45, step: 0.05)
                                Text("\(Int((style.scale * 100).rounded()))%")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 45, alignment: .trailing)
                            }
                        }
                    case .color:
                        Section("Цвет цифр и надписей") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                                ForEach(swatches, id: \.self) { hex in
                                    Button {
                                        style.textColorHex = hex
                                        customColor = Color(rgbHex: hex)
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    } label: {
                                        Circle()
                                            .fill(Color(rgbHex: hex))
                                            .frame(width: 46, height: 46)
                                            .overlay(Circle().stroke(.black.opacity(0.12), lineWidth: 1))
                                            .overlay {
                                                if style.textColorHex == hex {
                                                    Image(systemName: "checkmark")
                                                        .font(.headline.bold())
                                                        .foregroundStyle(hex == "FFFFFF" || hex == "F0E3D1" || hex == "C8E9FF" ? .black : .white)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Цвет \(hex)")
                                }
                            }
                            .padding(.vertical, 10)
                            ColorPicker("Свой цвет", selection: $customColor, supportsOpacity: false)
                                .onChange(of: customColor) { _, color in
                                    style.textColorHex = color.rgbHex
                                }
                        }
                        Section {
                            Text("Для фотографии можно отдельно изменить затемнение и цвет маски в настройках события.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    case .layout:
                        Section("Расположение числа") {
                            Picker("Выравнивание", selection: $style.alignment) {
                                ForEach(CardAlignment.allCases) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Section("Подпись единицы измерения") {
                            Picker("Положение", selection: $style.unitPlacement) {
                                ForEach(CardUnitPlacement.allCases) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Section {
                            Button("Вернуть оформление по умолчанию") {
                                style = CardStyle()
                                customColor = .white
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
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                customColor = Color(rgbHex: style.textColorHex)
            }
        }
    }
}
