<p align="center">
  <img src="assets/icon/adhkar_icon.png" width="112" alt="Azkar — a gold sun and crescent on antique green" />
</p>

<h1 align="center">أذكار · Azkar</h1>

<p align="center">A quiet space for morning and evening remembrance.</p>
<p align="center">Offline · No ads · No accounts · Open source</p>

Azkar is a simple Android app for reading **أذكار الصباح والمساء**. Arabic text, comfortable typography, and a tap-to-count reading experience help you focus on the dhikr.

## Download · تحميل التطبيق

**[Download Azkar 1.1.1 for Android (APK)](https://github.com/YouseifUS/azkar/releases/download/v1.1.1/Adhkar-v1.1.1.apk)** · [All releases](https://github.com/YouseifUS/azkar/releases/latest)

حمّل ملف APK وافتحه على هاتف Android لتثبيت التطبيق. قد تحتاج للسماح بالتثبيت من المتصفح أو مدير الملفات. مستخدمو النسخ السابقة يمكنهم تثبيت التحديث فوق النسخة الحالية.

## Screenshots

<p align="center">
  <img src="docs/screenshots/light-morning.png" width="300" alt="Morning adhkar in ivory, antique green and gold light mode" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/dark-evening.png" width="300" alt="Evening adhkar in navy and gold dark mode" />
</p>

<p align="center">Ivory, antique green & gold by day · Navy & gold by night</p>

These captures are rendered directly from the app's Flutter widgets at a phone-sized viewport, with the bundled Amiri font. They are not design mockups.

## Features

- 23 morning and 23 evening adhkar, including complete Quran passages.
- Light and dark modes. Use the small button **to the right of the counter**; your choice is remembered after reopening the app.
- A new sun-and-crescent launcher icon that brings morning and evening together.
- Tap the reading card or the circular counter to count. Completing a dhikr advances to the next one; swipe horizontally to browse.
- Separate morning/evening counters, saved locally.
- Automatic daily counter reset at the latest Fajr boundary, with a manual reset button and confirmation.
- Local reminders 30 minutes after Fajr and Asr, calculated using your device location, with periodic background schedule refresh.
- No ads, analytics, account, backend, or API key.

## الاستخدام

اختر أذكار الصباح أو المساء، ثم اضغط على بطاقة الذكر أو العداد للتسبيح. اسحب يمينًا أو يسارًا للتنقل. زر الشمس/الهلال على يمين العداد يبدّل بين الوضعين الفاتح والداكن ويحفظ اختيارك. زر إعادة الضبط على اليسار يصفّر العدادات بعد التأكيد.

للتذكير بعد الفجر والعصر بنصف ساعة، اسمح بالموقع والإشعارات عند الإعداد الأول. تُستخدم بيانات الموقع محليًا لحساب المواقيت.

## Run locally

The current project targets **Android**, with Flutter **3.47.2** / Dart **3.13.2**. Install Flutter and an Android SDK, then connect an Android device or start an emulator:

```sh
git clone https://github.com/YouseifUS/azkar.git
cd azkar
flutter pub get
flutter run
```

To build an installable APK:

```sh
flutter build apk --release
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`. The checked-in Android configuration currently uses the local debug signing key for release builds; configure your own release signing before store publication. Keep your signing keys private.

## Verify and contribute

```sh
flutter analyze
flutter test
```

Tests cover the adhkar document, prayer calculations, daily resets, permission handling, notification scheduling, reading gestures, counters, theme persistence, and both themes on a small phone.

Regenerate the README screenshots from the actual UI:

```sh
flutter test test/screenshots_test.dart --update-goldens --dart-define=GENERATE_SCREENSHOTS=true
```

Regenerate Android launcher assets after changing the icon:

```sh
dart run flutter_launcher_icons
```

Bug reports, translations, and pull requests are welcome. Please run the checks above before submitting changes.

## Text review · تدقيق النصوص

[Review notes and references](docs/content-audit.md) document the Arabic wording, punctuation, Quran stop marks, and corrections included in version 1.1.1.

## Privacy and reminders

Reading and counting work offline. Counters, theme preference, location coordinates, and timezone are stored locally on your device. This app does not send them to a server. Location and notification permissions are used for prayer reminders; reading remains available if you decline them. Delivery can depend on Android notification and battery settings. Font licensing is included in `assets/fonts/OFL.txt`.

## Open source · مفتوح المصدر

The code is released under the [MIT License](LICENSE). **Anyone may use, copy, modify, redistribute, or use it commercially**, provided the copyright notice and license are retained. The software is provided without warranty.

الكود مفتوح المصدر بترخيص MIT، ومتاح لأي شخص للاستخدام والنسخ والتعديل وإعادة التوزيع، حتى تجاريًا، مع الاحتفاظ بإشعار حقوق النشر ونص الترخيص.

Copyright © 2026 Yousef Mojahid.
