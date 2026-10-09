import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'models/adhkar.dart';

class AdhkarApp extends StatelessWidget {
  const AdhkarApp({
    super.key,
    required this.controller,
    this.activateDeviceServices = true,
  });

  final AppController controller;
  final bool activateDeviceServices;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'أذكار',
        theme: azkarTheme(Brightness.light),
        darkTheme: azkarTheme(Brightness.dark),
        themeMode: controller.lightThemeEnabled
            ? ThemeMode.light
            : ThemeMode.dark,
        themeAnimationDuration: const Duration(milliseconds: 240),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: AdhkarHome(
          controller: controller,
          activateDeviceServices: activateDeviceServices,
        ),
      ),
    );
  }
}

class AdhkarHome extends StatefulWidget {
  const AdhkarHome({
    super.key,
    required this.controller,
    required this.activateDeviceServices,
  });

  final AppController controller;
  final bool activateDeviceServices;

  @override
  State<AdhkarHome> createState() => _AdhkarHomeState();
}

class _AdhkarHomeState extends State<AdhkarHome> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  AdhkarPeriod _period = AdhkarPeriod.morning;
  int _pageIndex = 0;
  double _horizontalDrag = 0;
  bool _preparingDeviceServices = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.activateDeviceServices) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prepareDeviceServices();
      });
    }
  }

  Future<void> _prepareDeviceServices() async {
    _preparingDeviceServices = true;
    try {
      await _runDeviceSetup();
    } finally {
      _preparingDeviceServices = false;
    }
  }

  Future<void> _runDeviceSetup() async {
    final needsSetup = await widget.controller.needsPermissionSetup();
    if (!mounted) return;

    if (needsSetup) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('تفعيل التذكيرات'),
          content: const Text(
            'يحتاج التطبيق إذن الموقع لحساب موعدي الفجر '
            'والعصر على هاتفك فقط، وإذن الإشعارات لإرسال '
            'التذكير بعد الصلاة بنصف ساعة. لن تظهر المواقيت '
            'أو بيانات الموقع داخل التطبيق.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تفعيل الآن'),
            ),
          ],
        ),
      );
    }

    await widget.controller.activateDeviceServices(
      requestPermissions: needsSetup,
    );
    if (!mounted || !needsSetup) return;

    final permissionsStillMissing = await widget.controller
        .needsPermissionSetup();
    if (!mounted || !permissionsStillMissing) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الأذونات غير مفعلة'),
        content: const Text(
          'لن تعمل تذكيرات الصباح والمساء قبل السماح '
          'بالموقع والإشعارات من إعدادات التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await widget.controller.openApplicationSettings();
      if (mounted) {
        await widget.controller.activateDeviceServices(
          requestPermissions: false,
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_preparingDeviceServices) return;
      if (widget.activateDeviceServices) {
        widget.controller.activateDeviceServices(requestPermissions: false);
      } else {
        widget.controller.refreshAfterResume();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _selectPeriod(AdhkarPeriod period) {
    setState(() {
      _period = period;
      _pageIndex = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  void _finishHorizontalDrag(int itemCount) {
    if (_horizontalDrag.abs() < 50) return;
    final delta = _horizontalDrag > 0 ? 1 : -1;
    final target = (_pageIndex + delta).clamp(0, itemCount - 1);
    if (target == _pageIndex || !_pageController.hasClients) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _incrementAndAdvance(AdhkarItem item, int itemCount) async {
    final period = _period;
    final pageIndex = _pageIndex;
    final completed = await widget.controller.increment(period, item);
    if (!mounted ||
        !completed ||
        _period != period ||
        _pageIndex != pageIndex ||
        pageIndex >= itemCount - 1 ||
        !_pageController.hasClients) {
      return;
    }
    await _pageController.animateToPage(
      pageIndex + 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة ضبط العدادات'),
        content: const Text('هل تريد تصفير عدادات أذكار الصباح والمساء؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تصفير الكل'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final colors = context.azkarColors;
        final light = Theme.of(context).brightness == Brightness.light;
        final items = widget.controller.document.itemsFor(_period);
        final item = items[_pageIndex.clamp(0, items.length - 1)];
        final count = widget.controller.countFor(_period, item.order);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: light ? Brightness.light : Brightness.dark,
            statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: colors.backgroundBottom,
            systemNavigationBarIconBrightness: light
                ? Brightness.dark
                : Brightness.light,
          ),
          child: Scaffold(
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.backgroundTop,
                    colors.background,
                    colors.backgroundBottom,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                  child: Column(
                    children: [
                      _PeriodSelector(
                        selected: _period,
                        onSelected: _selectPeriod,
                      ),
                      const SizedBox(height: 18),
                      _ProgressPill(
                        current: _pageIndex + 1,
                        total: items.length,
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _incrementAndAdvance(item, items.length),
                          onHorizontalDragStart: (_) => _horizontalDrag = 0,
                          onHorizontalDragUpdate: (details) =>
                              _horizontalDrag += details.delta.dx,
                          onHorizontalDragEnd: (_) =>
                              _finishHorizontalDrag(items.length),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: PageView.builder(
                              controller: _pageController,
                              reverse: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              onPageChanged: (value) =>
                                  setState(() => _pageIndex = value),
                              itemBuilder: (context, index) => _DhikrCard(
                                key: ValueKey('${_period.storageKey}-$index'),
                                item: items[index],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 106,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _ResetButton(onPressed: _confirmReset),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _ThemeButton(
                                light: light,
                                onPressed: () =>
                                    widget.controller.toggleTheme(),
                              ),
                            ),
                            _CounterButton(
                              count: count,
                              target: item.repetition,
                              onPressed: () =>
                                  _incrementAndAdvance(item, items.length),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final AdhkarPeriod selected;
  final ValueChanged<AdhkarPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.azkarColors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _PeriodTab(
            label: 'أذكار الصباح',
            icon: Icons.wb_sunny_rounded,
            selected: selected == AdhkarPeriod.morning,
            onTap: () => onSelected(AdhkarPeriod.morning),
          ),
          _PeriodTab(
            label: 'أذكار المساء',
            icon: Icons.dark_mode_rounded,
            selected: selected == AdhkarPeriod.evening,
            onTap: () => onSelected(AdhkarPeriod.evening),
          ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.azkarColors;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? colors.selected : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: selected
                  ? Border.all(color: colors.accent.withValues(alpha: .45))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? const Color(0xFFE5C179) : colors.muted,
                  size: 20,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? colors.onSelected : colors.muted,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.azkarColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: _arabicDigits('$current'),
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: ' من ${_arabicDigits('$total')}'),
          ],
        ),
        style: TextStyle(color: colors.muted, fontSize: 16),
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({super.key, required this.item});

  final AdhkarItem item;

  double get _fontSize {
    if (item.text.length > 500) return 23;
    if (item.text.length > 330) return 25;
    if (item.text.length > 180) return 28;
    return 32;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.azkarColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _CardOrnament(color: colors.accent.withValues(alpha: .45)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 46, 24, 46),
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                item.text,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: colors.text,
                  fontSize: _fontSize,
                  height: 1.75,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.count,
    required this.target,
    required this.onPressed,
  });

  final int count;
  final int target;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.azkarColors;
    final complete = count >= target;
    final progress = target == 0 ? 0.0 : count / target;
    return Semantics(
      button: true,
      label: 'عداد الذكر: $count من $target',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 98,
          height: 98,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: progress.clamp(0, 1),
                  strokeWidth: 3,
                  backgroundColor: colors.border,
                  color: colors.accent,
                ),
              ),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.card,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: .18),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      complete ? '✓' : _arabicDigits('$count'),
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 31,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'من ${_arabicDigits('$target')}',
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.azkarColors;
    return Semantics(
      button: true,
      label: 'إعادة ضبط كل العدادات',
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'إعادة ضبط كل العدادات',
        icon: Icon(Icons.restart_alt_rounded, color: colors.muted, size: 28),
        style: IconButton.styleFrom(
          fixedSize: const Size(58, 58),
          backgroundColor: colors.surface,
          side: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.light, required this.onPressed});

  final bool light;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.azkarColors;
    return IconButton(
      key: const ValueKey('theme-toggle'),
      onPressed: onPressed,
      tooltip: light ? 'تفعيل الوضع الداكن' : 'تفعيل الوضع الفاتح',
      icon: Icon(
        light ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: colors.accent,
        size: 26,
      ),
      style: IconButton.styleFrom(
        fixedSize: const Size(58, 58),
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.border),
      ),
    );
  }
}

/// A quiet eight-point star and fine rules frame the text without competing
/// with it. Painting keeps the decoration out of accessibility and hit tests.
class _CardOrnament extends CustomPainter {
  const _CardOrnament({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    for (final y in [25.0, size.height - 25]) {
      final center = Offset(size.width / 2, y);
      canvas.drawLine(
        Offset(center.dx - 62, y),
        Offset(center.dx - 18, y),
        paint,
      );
      canvas.drawLine(
        Offset(center.dx + 18, y),
        Offset(center.dx + 62, y),
        paint,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawRect(const Rect.fromLTWH(-6, -6, 12, 12), paint);
      canvas.rotate(.7853981634);
      canvas.drawRect(const Rect.fromLTWH(-6, -6, 12, 12), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CardOrnament oldDelegate) =>
      color != oldDelegate.color;
}

String _arabicDigits(String value) {
  const western = '0123456789';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return value.split('').map((character) {
    final index = western.indexOf(character);
    return index == -1 ? character : arabic[index];
  }).join();
}
