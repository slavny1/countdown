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

## Widget/photo preview and restart (draft)

- Edit an event and tap **Открыть редактор карточки и виджетов** to preview **Карточка**, **Виджет** (small), or **Широкий** (medium) before saving.
- In the same live editor, choose a new image, gradient, tint overlay (the same eight swatches as typography), custom mask color and opacity. Adjust photo zoom (1–2.5×) and horizontal/vertical focal position. All settings are persisted per event for WidgetKit.
- Medium widgets have a different editorial composition: title and date on the left, large count on the right, over the background image.
- The detail page offers a small/medium widget preview and a **Настроить** button.
- **Сейчас** sets the current date and time. Enable **Считать время с этой даты** for elapsed time. **Начать заново** from the event detail sets the anchor to the current moment, including seconds.
- Photo save failures are now reported instead of silently losing the picture. Files and metadata use the same App Group shared with WidgetKit. iOS tinted/clear widget modes may override photo/color rendering; WidgetKit refreshes are scheduled but not guaranteed at exact minute intervals.

### iPhone acceptance tests

1. Save a photo event, check the card and the small/wide previews, then install real Home Screen widgets for the same event.
2. Verify photo positioning, overlay opacity, font color and clipping on both sizes, including after app restart.
3. Replace the photo, change crop and save. Verify widgets update; try a legacy event without these new fields.
4. Tap **Сейчас**, enable elapsed time, save, and press **Начать заново** in the detail page. Verify the number starts from zero.
5. Tap **Настроить** from the detail page and check the live editor.
6. Build the app, WidgetKit extension and tests in Xcode. GitHub connector changes are not compiled locally.

Existing signing, App Group and Copy only when installing build settings were left unchanged.

## Visual interaction pass (feat/card-interactions-v2)

- Event cards reveal a scrollable note panel underneath on tap. "Открыть событие" opens full details; events without a note still open directly.
- Long-press and drag to reorder cards; pin/unpin in the left-swipe menu. Pinned cards sort above unpinned cards; the pin icon is only visible on pinned cards.
- Cards and widget previews show the full date including year, and time when set. The event title uses the chosen font family/weight and responds to its scale.
- The event editor puts **Сейчас** beside the date and removes its redundant restart button. The subtle **Обнулить счётчик** action is at the bottom of event details.
- The event detail section is named **Виджеты**, with an icon settings control and vertically stacked small/wide previews.
- The live design editor uses explicit section buttons instead of a segmented Form; the layout tab is removed. Typography includes continuous size and stepped weight sliders.
- Added a fifth background gradient, plus reusable custom solid-color swatches via the + button. Photo masks offer two dark and two light swatches, plus custom colors stored in app preferences. Opacity stays adjustable. Photo-mask controls only show when a photo exists.
- The widget extension uses the same custom background color, font weight, font family, and scaling as event cards.

### iPhone verification checklist
1. Build both app and widget extension in Xcode and run tests. This GitHub integration has not executed Xcode.
2. Switch between typography, color, and background sections and verify controls really change the previews.
3. Expand a long note and scroll it independently; open full event details via the button.
4. Drag an event and pin/unpin via swipe; force-quit and reopen the app to verify ordering persists.
5. Test custom background and mask swatches, including after reopening the editor.
6. Compare small and wide WidgetKit instances with in-app previews after updating their event.
7. Check large numbers and heavy type at maximum slider values for clipping.
8. Verify reset is only available for elapsed-time events and appears after all event details.

This branch is based on feat/widget-photo-preview-reset, leaving main and prior feature branches unchanged. No project signing or widget-embedding settings were modified here.
