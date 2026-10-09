# React Native migration verification

Azkar 2.0.0 (version code 8) replaces the active Flutter implementation with React Native 0.86.3 and TypeScript. Flutter 1.1.2 source is preserved under `legacy/flutter` and is not part of the APK build.

## Preserved behavior and assets

- Canonical morning/evening JSON, 23 entries per period, unchanged byte for byte.
- Amiri regular/bold font files, licenses, launcher art and notification icon. The original Material Icons font and glyphs are reused for tab, theme and reset icons.
- Original light/dark semantic colors, dimensions, text-size thresholds, Arabic digits, layout, counter positions and confirmation wording.
- Separate capped counters, tap-to-count and auto-advance, horizontal RTL browsing and vertical scrolling for long passages.
- Application ID `com.yousefmojahid.adhkar_app` and existing signing certificate (SHA-256 `0cab55c228054aeb578479f2dd0b50857284bf7a04cfdd4abb077f622c44e00d`).
- Existing `FlutterSharedPreferences` file and prefixed keys for morning/evening counts, appearance, coordinates, timezone and last Fajr boundary. No destructive conversion.
- Egyptian/Shafi calculations, reminders 30 minutes after Fajr/Asr, 14-day horizon and 12-hour background refresh. Obsolete Flutter scheduled intents and background work are retired.

## Automated verification

`npm run validate`: TypeScript, lint, 7 React Native/content tests passed.

`./gradlew testDebugUnitTest assembleRelease`: 7 Android regression tests passed; signed universal release APK built successfully.

Android tests cover existing Flutter preference values, independent/capped counters, theme retention, manual reset, before/at/after-Fajr idempotence, next Fajr, 28 alarms for a 14-day horizon, idempotent rescheduling, missing-location fallback, and Android 7 compatibility without notification channels.

Seven date/location fixtures were computed with the original Dart `adhan` library and matched exactly by the Android prayer bridge, including Cairo, London, year boundaries, leap day and Egyptian DST transition dates. Adhan Java's retained Calendar milliseconds are normalized so recalculated Fajr boundaries are deterministic and match Dart timestamps.

## Device verification

Passed on an Android 15 ARM64 emulator using the signed release APK, without Metro:

- Installed Flutter 1.1.2, stored separate morning/evening counters, appearance, location, timezone and current Fajr boundary, then installed React Native in place. All saved values survived, including after service activation.
- Compared the same morning/evening entries and light/dark themes in both implementations on the same 412 x 920 logical display. Matched tab and progress text bounds, fonts, icon glyphs, controls, palette and reading layout. README screenshots now come from the React Native release.
- Verified card/counter taps, auto-advance, RTL swipes, reset cancellation/confirmation, saved appearance, vertical reading gestures without counting, and a 320 x 640 logical phone.
- Confirmed 26 future prayer reminder alarms (both of today's reminders were already past) and the 12-hour `PrayerRefreshWorker` system job.
- Posted the actual native evening notification while the application was backgrounded by invoking its receiver. This verifies receiver/channel/content delivery; it does not simulate waiting for a scheduled prayer alarm.
- No application crashes or React Native JavaScript errors appeared in the device log.

A device test caught vertical drags counting as taps on cards whose text fits without scrolling. The final implementation cancels card counting after touch movement; a dedicated React Native regression test and the repeated device test pass.

## Limits

Android is the supported platform, matching the original project. OEM battery policies and force-stop behavior still govern reminder delivery. No physical phone is connected in this environment; long-running real-device reminder delivery has not been tested here. Differences in platform text rasterization and animation between Flutter and React Native may remain despite matching assets and layout values.
