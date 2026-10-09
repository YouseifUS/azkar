import 'package:adhkar_app/adhkar_app.dart';
import 'package:adhkar_app/app_controller.dart';
import 'package:adhkar_app/models/adhkar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'theme toggle is on the right and preserves reading progress across relaunch',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = (await tester.runAsync(AppController.create))!;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        AdhkarApp(controller: controller, activateDeviceServices: false),
      );
      await tester.pumpAndSettle();

      Brightness brightness() =>
          Theme.of(tester.element(find.byType(Scaffold))).brightness;
      expect(brightness(), Brightness.dark);
      await tester.tap(find.text('أذكار المساء'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(350, 0));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('theme-toggle'));
      expect(
        tester.getCenter(toggle).dx,
        greaterThan(tester.getCenter(find.byType(Scaffold)).dx),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      expect(find.text('٢ من ٢٣'), findsOneWidget);
      expect(find.byTooltip('تفعيل الوضع الداكن'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Counter reset must not reset the saved appearance preference.
      await controller.resetAll();
      expect(controller.lightThemeEnabled, isTrue);
      final reloaded = (await tester.runAsync(AppController.create))!;
      addTearDown(reloaded.dispose);
      expect(reloaded.lightThemeEnabled, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        AdhkarApp(controller: reloaded, activateDeviceServices: false),
      );
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      final again = (await tester.runAsync(AppController.create))!;
      addTearDown(again.dispose);
      expect(again.lightThemeEnabled, isFalse);
    },
  );

  for (final light in [false, true]) {
    testWidgets(
      'reading and reset work in ${light ? 'light' : 'dark'} mode on a small phone',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({'light_theme_enabled': light});
        final controller = (await tester.runAsync(AppController.create))!;
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          AdhkarApp(controller: controller, activateDeviceServices: false),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('الحمد لله وحده، والصلاة والسلام على من لا نبي بعده.'),
        );
        await tester.pumpAndSettle();
        expect(controller.countFor(AdhkarPeriod.morning, 1), 1);
        expect(find.text('٢ من ٢٣'), findsOneWidget);
        await tester.tap(find.byTooltip('إعادة ضبط كل العدادات'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('تصفير الكل'));
        await tester.pumpAndSettle();
        expect(controller.countFor(AdhkarPeriod.morning, 1), 0);
        expect(controller.lightThemeEnabled, light);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('card tap, counter, period selection, and swipe work', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = (await tester.runAsync(AppController.create))!;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AdhkarApp(controller: controller, activateDeviceServices: false),
    );
    await tester.pump();

    expect(find.text('أذكار الصباح'), findsOneWidget);
    expect(find.text('أذكار'), findsNothing);
    expect(
      find.text('الحمد لله وحده، والصلاة والسلام على من لا نبي بعده.'),
      findsOneWidget,
    );
    expect(find.text('١ من ٢٣'), findsOneWidget);

    await tester.tap(
      find.text('الحمد لله وحده، والصلاة والسلام على من لا نبي بعده.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('٢ من ٢٣'), findsOneWidget);
    expect(
      find.textContaining('اللَّهُ لَا إِلَهَ إِلَّا هُوَ'),
      findsOneWidget,
    );

    await tester.tap(find.text('أذكار المساء'));
    await tester.pump();
    expect(find.text('١ من ٢٣'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is InkWell && widget.customBorder is CircleBorder,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('٢ من ٢٣'), findsOneWidget);

    await tester.tap(find.text('أذكار الصباح'));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(350, 0));
    await tester.pumpAndSettle();

    expect(find.text('٢ من ٢٣'), findsOneWidget);
    expect(
      find.textContaining('اللَّهُ لَا إِلَهَ إِلَّا هُوَ'),
      findsOneWidget,
    );
  });
}
