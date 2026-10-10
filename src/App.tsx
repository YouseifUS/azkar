import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Animated,
  AppState,
  Linking,
  Modal,
  PanResponder,
  Platform,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import LinearGradient from 'react-native-linear-gradient';
import Svg, { Circle } from 'react-native-svg';
import {
  arabic,
  colors,
  document,
  fontSize,
  isPeriodComplete,
  targetPage,
} from './model';
import type { Period, Snapshot } from './model';
import { device, requestPermissions } from './device';

function Icon({
  name,
  color,
  size = 26,
}: {
  name: 'sun' | 'light' | 'moon' | 'reset';
  color: string;
  size?: number;
}) {
  const glyph = { sun: 0xf02ae, light: 0xf852, moon: 0xf68c, reset: 0xf0106 }[
    name
  ];
  return (
    <Text
      accessible={false}
      style={{
        fontFamily: 'MaterialIcons-Regular',
        fontSize: size,
        lineHeight: size,
        width: size,
        height: size,
        color,
        textAlign: 'center',
        includeFontPadding: false,
      }}
    >
      {String.fromCodePoint(glyph)}
    </Text>
  );
}

type DialogAction = { text: string; style?: string; onPress?: () => void };
type DialogState = {
  title: string;
  body: string;
  actions: DialogAction[];
  cancelable: boolean;
};
function Home() {
  const [state, setState] = useState<Snapshot>();
  const [period, setPeriod] = useState<Period>('morning');
  const [page, setPage] = useState(0);
  const [failed, setFailed] = useState(false);
  const [dialog, setDialog] = useState<DialogState>();
  const showDialog = useCallback(
    (
      title: string,
      body: string,
      actions: DialogAction[] = [{ text: 'حسنًا' }],
      options = { cancelable: true },
    ) => {
      setDialog({ title, body, actions, cancelable: options.cancelable });
    },
    [],
  );
  const position = useRef({ period, page });
  position.current = { period, page };
  const busy = useRef(false);
  const cardTouch = useRef({ x: 0, y: 0, moved: false });
  const preparing = useRef(false);
  const live = useRef(true);
  const scroll = useRef<ScrollView>(null);
  const fade = useRef(new Animated.Value(1)).current;
  const slide = useRef(new Animated.Value(0)).current;
  const items = document[period];
  const item = items[page];
  const c = state?.light ? colors.light : colors.dark;
  const count = state?.[period][String(item.order)] ?? 0;
  const apply = useCallback((next: Snapshot) => {
    if (live.current) setState(next);
  }, []);
  const report = useCallback(() => {
    if (live.current) showDialog('تعذر حفظ التغيير', 'حاول مرة أخرى.');
  }, [showDialog]);
  const activate = useCallback(async () => {
    if (preparing.current) return;
    preparing.current = true;
    try {
      apply(await device.activate());
    } catch {
      /* Reading stays available without device services. */
    } finally {
      preparing.current = false;
    }
  }, [apply]);
  useEffect(() => {
    live.current = true;
    const start = async () => {
      try {
        apply(await device.load());
        const permission = await device.permissions();
        if (!live.current) return;
        if (!permission.location || !permission.notifications) {
          showDialog(
            'تفعيل التذكيرات',
            'يحتاج التطبيق إذن الموقع لحساب موعدي الفجر والعصر على هاتفك فقط، وإذن الإشعارات لإرسال التذكير بعد الصلاة بنصف ساعة. لن تظهر المواقيت أو بيانات الموقع داخل التطبيق.',
            [
              {
                text: 'تفعيل الآن',
                onPress: () => {
                  preparing.current = true;
                  void (async () => {
                    try {
                      await requestPermissions();
                      apply(await device.activate());
                      const allowed = await device.permissions();
                      if (
                        live.current &&
                        (!allowed.location || !allowed.notifications)
                      ) {
                        showDialog(
                          'الأذونات غير مفعلة',
                          'لن تعمل تذكيرات الصباح والمساء قبل السماح بالموقع والإشعارات من إعدادات التطبيق.',
                          [
                            { text: 'لاحقًا', style: 'cancel' },
                            {
                              text: 'فتح الإعدادات',
                              onPress: () => {
                                void Linking.openSettings();
                              },
                            },
                          ],
                        );
                      }
                    } catch {
                      /* Permission refusal does not block reading. */
                    } finally {
                      preparing.current = false;
                    }
                  })();
                },
              },
            ],
            { cancelable: false },
          );
        } else {
          await activate();
        }
      } catch {
        if (live.current) setFailed(true);
      }
    };
    void start();
    const listener = AppState.addEventListener('change', value => {
      if (value === 'active') void activate();
    });
    return () => {
      live.current = false;
      listener.remove();
    };
  }, [activate, apply, showDialog]);
  useEffect(() => {
    if (!state?.nextFajr) return;
    const delay = Math.max(100, state.nextFajr - Date.now() + 50);
    const timer = setTimeout(() => {
      void activate();
    }, Math.min(delay, 2147483647));
    return () => clearTimeout(timer);
  }, [state?.nextFajr, activate]);
  function move(next: number) {
    if (next === position.current.page) return;
    const direction = next > position.current.page ? -1 : 1;
    position.current.page = next;
    setPage(next);
    scroll.current?.scrollTo({ y: 0, animated: false });
    fade.setValue(0.65);
    slide.setValue(direction * 22);
    Animated.parallel([
      Animated.timing(fade, {
        toValue: 1,
        duration: 260,
        useNativeDriver: true,
      }),
      Animated.timing(slide, {
        toValue: 0,
        duration: 260,
        useNativeDriver: true,
      }),
    ]).start();
  }
  const pan = useRef(
    PanResponder.create({
      onMoveShouldSetPanResponder: (_, g) =>
        Math.abs(g.dx) > 12 && Math.abs(g.dx) > Math.abs(g.dy) * 1.4,
      onPanResponderRelease: (_, g) => {
        const current = position.current;
        move(targetPage(current.page, g.dx, document[current.period].length));
      },
    }),
  ).current;
  async function increment() {
    if (!state || busy.current) return;
    busy.current = true;
    const current = { ...position.current };
    const dhikr = document[current.period][current.page];
    const before = state[current.period][String(dhikr.order)] ?? 0;
    try {
      const next = await device.increment(current.period, dhikr.order);
      apply(next);
      if (
        !isPeriodComplete(current.period, state[current.period]) &&
        isPeriodComplete(current.period, next[current.period]) &&
        live.current
      ) {
        showDialog(
          'تم ورد اليوم',
          current.period === 'morning'
            ? 'أتممت جميع أذكار الصباح.'
            : 'أتممت جميع أذكار المساء.',
        );
      }
      if (
        before < dhikr.repetition &&
        next[current.period][String(dhikr.order)] >= dhikr.repetition &&
        current.period === position.current.period &&
        current.page === position.current.page &&
        current.page < document[current.period].length - 1
      ) {
        move(current.page + 1);
      }
    } catch {
      report();
    } finally {
      busy.current = false;
    }
  }
  function select(value: Period) {
    position.current = { period: value, page: 0 };
    setPeriod(value);
    setPage(0);
    scroll.current?.scrollTo({ y: 0, animated: false });
  }
  function reset() {
    showDialog(
      'إعادة ضبط العدادات',
      'هل تريد تصفير عدادات أذكار الصباح والمساء؟',
      [
        { text: 'إلغاء', style: 'cancel' },
        {
          text: 'تصفير الكل',
          onPress: () => {
            void device.reset().then(apply).catch(report);
          },
        },
      ],
    );
  }
  const ringLength = 2 * Math.PI * 46.5;
  return (
    <LinearGradient
      colors={[c.top, c.background, c.bottom]}
      style={styles.fill}
    >
      <Modal
        visible={Boolean(dialog)}
        transparent
        animationType="fade"
        statusBarTranslucent
        onRequestClose={() => {
          if (dialog?.cancelable) setDialog(undefined);
        }}
      >
        <Pressable
          style={styles.dialogBackdrop}
          onPress={() => {
            if (dialog?.cancelable) setDialog(undefined);
          }}
        >
          <Pressable
            style={[styles.dialog, { backgroundColor: c.card }]}
            onPress={() => {}}
            accessibilityViewIsModal
          >
            <Text
              testID="dialog-title"
              style={[styles.dialogTitle, { color: c.text }]}
            >
              {dialog?.title}
            </Text>
            <Text style={[styles.dialogBody, { color: c.text }]}>
              {dialog?.body}
            </Text>
            <View style={styles.dialogActions}>
              {dialog?.actions.map((action, index) => (
                <Pressable
                  key={action.text}
                  testID={`dialog-action-${index}`}
                  accessibilityRole="button"
                  accessibilityLabel={action.text}
                  style={[
                    styles.dialogAction,
                    action.style !== 'cancel' && { backgroundColor: c.accent },
                  ]}
                  onPress={() => {
                    setDialog(undefined);
                    action.onPress?.();
                  }}
                >
                  <Text
                    style={[
                      styles.dialogActionText,
                      {
                        color:
                          action.style === 'cancel'
                            ? c.accent
                            : state?.light
                            ? '#FFFFFF'
                            : c.background,
                      },
                    ]}
                  >
                    {action.text}
                  </Text>
                </Pressable>
              ))}
            </View>
          </Pressable>
        </Pressable>
      </Modal>
      <StatusBar barStyle={state?.light ? 'dark-content' : 'light-content'} />
      <SafeAreaView style={styles.fill}>
        <View style={styles.layout}>
          <View
            style={[
              styles.selector,
              { backgroundColor: c.surface, borderColor: c.border },
            ]}
          >
            {(['evening', 'morning'] as Period[]).map(value => (
              <Pressable
                key={value}
                testID={`period-${value}`}
                accessibilityRole="button"
                accessibilityState={{ selected: period === value }}
                accessibilityLabel={`${
                  value === 'morning' ? 'أذكار الصباح' : 'أذكار المساء'
                }${
                  state && isPeriodComplete(value, state[value])
                    ? '، تم الورد'
                    : ''
                }`}
                onPress={() => select(value)}
                style={[
                  styles.tab,
                  {
                    backgroundColor:
                      period === value ? c.selected : 'transparent',
                    borderColor:
                      period === value ? `${c.accent}73` : 'transparent',
                  },
                ]}
              >
                <Text
                  numberOfLines={1}
                  adjustsFontSizeToFit
                  style={[
                    styles.tabText,
                    { color: period === value ? c.onSelected : c.muted },
                  ]}
                >
                  {value === 'morning' ? 'أذكار الصباح' : 'أذكار المساء'}
                </Text>
                {state && isPeriodComplete(value, state[value]) && (
                  <Text
                    testID={`complete-${value}`}
                    accessible={false}
                    style={[
                      styles.tabCheck,
                      { color: period === value ? c.onSelected : c.accent },
                    ]}
                  >
                    ✓
                  </Text>
                )}
                <Icon
                  name={value === 'morning' ? 'sun' : 'moon'}
                  size={20}
                  color={period === value ? '#E5C179' : c.muted}
                />
              </Pressable>
            ))}
          </View>
          <View
            style={[
              styles.pill,
              { backgroundColor: c.surface, borderColor: c.border },
            ]}
          >
            <Text
              testID="page-progress"
              style={[styles.pillText, { color: c.muted }]}
            >
              <Text style={{ color: c.accent, fontFamily: 'Amiri-Bold' }}>
                {arabic(page + 1)}
              </Text>
              {` من ${arabic(items.length)}`}
            </Text>
          </View>
          <View
            style={[
              styles.card,
              {
                backgroundColor: c.card,
                borderColor: c.border,
                boxShadow:
                  Number(Platform.Version) >= 28
                    ? [
                        {
                          offsetX: 0,
                          offsetY: 12,
                          blurRadius: 22,
                          color: state?.light ? '#183E3518' : '#00000042',
                        },
                      ]
                    : undefined,
              },
            ]}
            {...pan.panHandlers}
          >
            {!state ? (
              <View style={styles.loading}>
                {failed ? (
                  <Text style={[styles.error, { color: c.text }]}>
                    تعذر تحميل البيانات. أعد فتح التطبيق.
                  </Text>
                ) : (
                  <ActivityIndicator color={c.accent} />
                )}
              </View>
            ) : (
              <Animated.View
                style={[
                  styles.fill,
                  { opacity: fade, transform: [{ translateX: slide }] },
                ]}
              >
                <ScrollView
                  ref={scroll}
                  showsVerticalScrollIndicator={false}
                  contentContainerStyle={styles.scroll}
                >
                  <Pressable
                    testID="reading-card"
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={item.text}
                    onTouchStart={event => {
                      cardTouch.current = {
                        x: event.nativeEvent.pageX,
                        y: event.nativeEvent.pageY,
                        moved: false,
                      };
                    }}
                    onTouchMove={event => {
                      if (
                        Math.abs(
                          event.nativeEvent.pageX - cardTouch.current.x,
                        ) > 8 ||
                        Math.abs(
                          event.nativeEvent.pageY - cardTouch.current.y,
                        ) > 8
                      )
                        cardTouch.current.moved = true;
                    }}
                    onPress={() => {
                      const moved = cardTouch.current.moved;
                      cardTouch.current.moved = false;
                      if (!moved) void increment();
                    }}
                    style={styles.reading}
                  >
                    <Text
                      style={[
                        styles.dhikr,
                        {
                          color: c.text,
                          fontSize: fontSize(item.text),
                          lineHeight: fontSize(item.text) * 1.75,
                        },
                      ]}
                    >
                      {item.text}
                    </Text>
                  </Pressable>
                </ScrollView>
              </Animated.View>
            )}
          </View>
          <View style={styles.controls}>
            <Pressable
              testID="reset"
              accessibilityRole="button"
              accessibilityLabel="إعادة ضبط كل العدادات"
              onPress={reset}
              style={[
                styles.smallButton,
                { backgroundColor: c.surface, borderColor: c.border },
              ]}
            >
              <Icon name="reset" size={28} color={c.muted} />
            </Pressable>
            <Pressable
              testID="counter"
              accessibilityRole="button"
              accessibilityLabel={`عداد الذكر: ${count} من ${item.repetition}`}
              onPress={() => {
                void increment();
              }}
              style={styles.counter}
            >
              <Svg width="98" height="98" style={StyleSheet.absoluteFill}>
                <Circle
                  cx="49"
                  cy="49"
                  r="46.5"
                  fill="none"
                  stroke={c.border}
                  strokeWidth="3"
                />
                <Circle
                  cx="49"
                  cy="49"
                  r="46.5"
                  fill="none"
                  stroke={c.accent}
                  strokeWidth="3"
                  strokeDasharray={`${ringLength} ${ringLength}`}
                  strokeDashoffset={
                    ringLength * (1 - Math.min(1, count / item.repetition))
                  }
                  rotation="-90"
                  origin="49,49"
                />
              </Svg>
              <View style={[styles.counterInside, { backgroundColor: c.card }]}>
                <Text style={[styles.count, { color: c.accent }]}>
                  {count >= item.repetition ? '✓' : arabic(count)}
                </Text>
                <Text style={[styles.target, { color: c.muted }]}>{`من ${arabic(
                  item.repetition,
                )}`}</Text>
              </View>
            </Pressable>
            <Pressable
              testID="theme-toggle"
              accessibilityRole="button"
              accessibilityLabel={
                state?.light ? 'تفعيل الوضع الداكن' : 'تفعيل الوضع الفاتح'
              }
              onPress={() => {
                if (state)
                  void device.setLight(!state.light).then(apply).catch(report);
              }}
              style={[
                styles.smallButton,
                { backgroundColor: c.surface, borderColor: c.border },
              ]}
            >
              <Icon name={state?.light ? 'moon' : 'light'} color={c.accent} />
            </Pressable>
          </View>
        </View>
      </SafeAreaView>
    </LinearGradient>
  );
}
export default function App() {
  return (
    <SafeAreaProvider>
      <Home />
    </SafeAreaProvider>
  );
}
const styles = StyleSheet.create({
  fill: { flex: 1 },
  layout: {
    flex: 1,
    paddingHorizontal: 22,
    paddingTop: 12,
    paddingBottom: 18,
    direction: 'ltr',
  },
  selector: {
    flexDirection: 'row',
    borderRadius: 28,
    borderWidth: 1,
    padding: 4,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 7,
    paddingVertical: 10,
    borderRadius: 24,
    borderWidth: 1,
  },
  tabText: {
    fontFamily: 'Amiri-Bold',
    fontSize: 18,
    lineHeight: 26,
    writingDirection: 'rtl',
    includeFontPadding: false,
    flexShrink: 1,
  },
  tabCheck: {
    fontSize: 18,
    lineHeight: 26,
    includeFontPadding: false,
  },
  pill: {
    alignSelf: 'center',
    marginTop: 18,
    marginBottom: 14,
    paddingHorizontal: 18,
    paddingVertical: 6,
    borderRadius: 22,
    borderWidth: 1,
  },
  pillText: {
    fontFamily: 'Amiri-Regular',
    fontSize: 16,
    lineHeight: 23,
    writingDirection: 'rtl',
    textAlign: 'center',
    includeFontPadding: false,
  },
  card: {
    flex: 1,
    borderRadius: 30,
    borderWidth: 1,
    elevation: Number(Platform.Version) < 28 ? 2 : 0,
    overflow: 'hidden',
  },
  scroll: { flexGrow: 1 },
  reading: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
    paddingVertical: 46,
  },
  dhikr: {
    fontFamily: 'Amiri-Regular',
    textAlign: 'center',
    writingDirection: 'rtl',
    includeFontPadding: false,
  },
  controls: {
    height: 106,
    marginTop: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  smallButton: {
    width: 58,
    height: 58,
    borderRadius: 29,
    borderWidth: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  counter: {
    width: 98,
    height: 98,
    justifyContent: 'center',
    alignItems: 'center',
  },
  counterInside: {
    width: 84,
    height: 84,
    borderRadius: 42,
    justifyContent: 'center',
    alignItems: 'center',
  },
  count: {
    fontFamily: 'Amiri-Bold',
    fontSize: 31,
    lineHeight: 31,
    includeFontPadding: false,
  },
  target: {
    fontFamily: 'Amiri-Regular',
    fontSize: 13,
    lineHeight: 19,
    marginTop: 5,
    includeFontPadding: false,
  },
  dialogBackdrop: {
    flex: 1,
    backgroundColor: '#00000088',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
  },
  dialog: { width: '100%', maxWidth: 560, borderRadius: 28, padding: 24 },
  dialogTitle: {
    fontFamily: 'Amiri-Regular',
    fontSize: 24,
    textAlign: 'right',
    writingDirection: 'rtl',
    marginBottom: 16,
  },
  dialogBody: {
    fontFamily: 'Amiri-Regular',
    fontSize: 18,
    lineHeight: 28,
    textAlign: 'right',
    writingDirection: 'rtl',
  },
  dialogActions: { flexDirection: 'row-reverse', gap: 8, marginTop: 24 },
  dialogAction: { paddingHorizontal: 18, paddingVertical: 8, borderRadius: 24 },
  dialogActionText: { fontFamily: 'Amiri-Regular', fontSize: 16 },
  loading: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  error: { fontFamily: 'Amiri-Regular', fontSize: 22, textAlign: 'center' },
});
