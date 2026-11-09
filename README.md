# CountDown

An expressive SwiftUI date counter for iPhone. Save the days you are waiting for and the milestones you want to remember.

## MVP

- Add, edit, and delete events.
- Calendar-day counting: upcoming, today, and elapsed days.
- Four gradient themes and a selection of SF Symbols.
- Local JSON persistence; shared App Group storage for widgets.
- Russian UI, VoiceOver labels and Reduce Motion support.
- Home Screen and Lock Screen widgets (see widget target).

## Build

Open `CountDown.xcodeproj` in Xcode 16.3 or newer; select the CountDown scheme and an iPhone simulator. The deployment target is iOS 18.4.

For device signing and widget data sharing, register the App Group
`group.com.slavny1.countdown` in your Apple Developer account and enable it for both the app and widget extension. Set your Apple development team in Signing & Capabilities.

Run unit tests from Xcode with Cmd+U. No simulator or signing environment is available through the GitHub connector; builds/tests must be verified on a Mac.

## Calendar semantics

Events store **year/month/day** rather than a timestamp. They keep the same displayed calendar date when you change time zones. Days are counted between the starts of local calendar days (not as 24-hour durations), so daylight saving changes do not shift the count.

## Next

- Widget event selection (WidgetKit App Intents).
- Local notifications and repeat/anniversary options.
- Customization, delightful animation and haptics.
- English localization, onboarding, App Store assets.
