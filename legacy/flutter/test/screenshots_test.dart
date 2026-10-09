import 'package:adhkar_app/adhkar_app.dart';
import 'package:adhkar_app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in captures of the real Flutter widgets, not design mockups.
/// flutter test test/screenshots_test.dart --update-goldens \
///   --dart-define=GENERATE_SCREENSHOTS=true
void main() {
  for (final light in [true, false]) {
    final name = light ? 'light-morning' : 'dark-evening';
    testWidgets('capture $name', (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('Amiri')
          ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
        await font.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      SharedPreferences.setMockInitialValues({'light_theme_enabled': light});
      final controller = (await tester.runAsync(AppController.create))!;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('screenshot'),
          child: AdhkarApp(
            controller: controller,
            activateDeviceServices: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!light) {
        await tester.tap(find.text('أذكار المساء'));
        await tester.pumpAndSettle();
      }
      for (var page = 0; page < 5; page++) {
        await tester.drag(find.byType(PageView), const Offset(350, 0));
        await tester.pumpAndSettle();
      }
      expect(find.text('٦ من ٢٣'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('screenshot')),
        matchesGoldenFile('../docs/screenshots/$name.png'),
      );
    }, skip: !const bool.fromEnvironment('GENERATE_SCREENSHOTS'));
  }
}
