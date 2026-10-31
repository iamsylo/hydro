# Hydro

Hydro is a polished Flutter hydration tracker for Android. It helps users set
a daily water goal, log drinks quickly, understand their progress, and receive
gentle reminders during their preferred active hours.

## Features

- Four-step first-launch onboarding
- Custom daily water goals
- mL and oz display units
- Quick-add water buttons and manual custom entries
- Persistent water history stored locally on the device
- Undo feedback after logging a drink
- Large-entry confirmation
- Goal progress ring with over-goal intake support
- Mascot states that respond to hydration progress and time of day
- Insights with weekly and monthly history
- Daily history details, editing, and deletion
- Reminder settings for:
  - Active start and end times
  - 30 minutes, 1 hour, 1.5 hours, 2 hours, 3 hours, or Custom intervals
  - Sound and vibration
  - Stopping routine reminders after reaching the daily goal
  - 30-minute snooze
- Android local notifications that continue while the app is closed
- Light, dark, and system appearance options
- Reduced-animation and mascot-animation preferences
- About Hydro, privacy, terms, licenses, and feedback screens
- Responsive layouts for small phones, large phones, tablets, and landscape

## Technology

- Flutter and Dart
- Material 3
- `shared_preferences` for local preferences and water entries
- `flutter_local_notifications` for Android reminders
- `timezone` for scheduled reminder times
- `url_launcher` for feedback links
- `package_info_plus` for app version information

## Requirements

- Flutter SDK compatible with the Dart constraint in `pubspec.yaml`
- Android SDK and an Android emulator or physical device
- Android notification permission enabled for reminders

## Getting started

Install dependencies:

```bash
flutter pub get
```

Run on a connected device or emulator:

```bash
flutter run
```

Build a debug APK:

```bash
flutter build apk --debug
```

Build a release APK:

```bash
flutter build apk --release
```

## Notifications

Hydro requests notification permission when reminders are enabled. Reminder
times are scheduled locally on the device using the configured active hours and
interval. Notifications are canceled when reminders are disabled and paused
after the daily goal when the stop-after-goal option is enabled.

Android may restrict background notifications through battery optimization or
device-specific power-management settings. If reminders do not appear, verify
that Hydro has notification permission and is allowed to run in the background.

## Data and privacy

Hydro stores water entries and preferences locally using Android application
storage. The app does not require an account or a remote backend. Clearing app
data or using Reset App Data removes the locally stored history and settings.

## Project structure

```text
lib/
  main.dart
  src/
    app.dart
    home/
      home_screen.dart
    notifications/
      notification_service.dart
    onboarding/
      onboarding_screen.dart
assets/
  images/
android/
  app/
```

Most of the current application flow is contained in
`lib/src/home/home_screen.dart`, including Home, Insights, Reminders, Settings,
About, and local history interactions.

## Validation

Run static analysis:

```bash
flutter analyze
```

Run the available test suite:

```bash
flutter test
```

The project may report non-blocking analyzer suggestions about `const`
constructors and asynchronous `BuildContext` usage. These do not prevent
debug or release builds.
