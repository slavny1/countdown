# Дни · CountDown

A visual SwiftUI date counter for iOS 18.4+, with WidgetKit widgets for the Home Screen and Lock Screen.

## What's new

- Compact event cards, elegant serif numerals, Russian app display name **Дни**.
- Events show “Осталось” or “Прошло”, with the unit label beside the number.
- Each event has automatic/days/hours/minutes units; automatic shows days until the last 24 hours, hours until the last hour, and minutes in the final hour. Events in the past default to calendar days. Optional time-of-day lets you set an exact deadline.
- Tap an event for its detail and note; swipe left for **Изменить** or **Удалить**.
- Choose a photo background, mask color and mask opacity; photos save to the shared App Group container for widget display.
- Optional round-date milestones: 1, 7, 10, 30, 50, 100, 200 days; 1 month, 6 months, and 1/2/5/10 years.
- The first launch seeds an example event for April 30, 2026. Pre-existing saved events are retained and decoded with defaults for new fields.
- Configurable widgets: **long-press a widget → Edit Widget → Событие**, choose an event independently for each widget. No selection defaults to the nearest upcoming event or most recent past one.
- Larger typography in widgets, with calendar-aware day counting and short WidgetKit timeline refresh intervals near the deadline.

## Build & test

1. Open `CountDown.xcodeproj` in Xcode 16.3+.
2. Select the main app scheme and target an iPhone (iOS 18.4+). Existing Developer Team, signing and Copy only when installing settings are **preserved** in this branch.
3. Ensure App Groups `group.com.slavny1.countdown` is enabled on **both** CountDown and CountDownWidgets.
4. Build both targets, install the app and add the widget. Long-press the widget and choose **Изменить виджет → Событие**.
5. Test legacy event migration, photos, manual vs automatic units, and midnight/DST boundaries.

Compilation / widget installation on a physical iPhone still require local Xcode verification; GitHub connector writes don't run `xcodebuild`.

## Potential next features

Notifications for milestones; repeat annual events; pinned/favorite event; iCloud sync; layout presets; export/shareable day cards; smart widget stacks.

## Visual card customizer (draft)

In an event's edit sheet, tap **Настроить стиль** to open a live card preview inspired by the iOS Lock Screen clock editor. Three sections provide:

- **Шрифт**: editorial serif, standard sans, rounded, or monospaced numerals; six weights and a 75–145% size slider.
- **Цвет**: eight curated swatches plus an iOS Color Picker.
- **Макет**: left/center alignment and unit labels beside or below the number, with a reset action.

Appearance persists per event and is read by Home Screen widgets. Lock Screen accessory widgets have system-controlled tinting and limited layout, so iOS may override custom color there. Existing events default to the original serif/white style.

**Build note:** The customizer has been committed to a separate feature branch, but Xcode compilation and device validation have not been run by the GitHub integration. Run the app and Widget extension builds in Xcode before merging. The existing signing, Bundle ID, App Group, and Copy only when installing settings are unchanged.
