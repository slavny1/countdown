# CountDown

SwiftUI day counter for iPhone with WidgetKit Home Screen and Lock Screen widgets.

## Features

Create, edit and delete calendar-date events, with four gradients and SF Symbols. The app counts calendar days until, on and since an event; JSON data persists through App Groups. The widget selects the nearest upcoming event, then the most recent past event. Includes Russian UI and unit tests for DST, leap years, and Russian day word forms.

## Build

Open `CountDown.xcodeproj` in Xcode 16.3+. Select the CountDown scheme and iPhone simulator (iOS 18.4+). To sign for a physical device, select your Apple Development Team for **both** app and extension and register/enable `group.com.slavny1.countdown` in both targets' App Groups. The identifier is a proposed value and must exist in your Developer account.

Run tests via Cmd+U. Compilation and iPhone signing have not been verified in Xcode. Widget refresh is scheduled after local midnight and when events change.

## Next

Choose events for individual widgets via App Intents, reminders, recurring anniversaries, localization, more polished motion, onboarding.
