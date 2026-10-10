import React from 'react';
import renderer, { act } from 'react-test-renderer';
import { AppState, NativeModules } from 'react-native';
import { document } from '../src/model';
import type { Snapshot } from '../src/model';

jest.mock('react-native-linear-gradient', () => 'LinearGradient');
jest.mock('react-native-svg', () => ({
  __esModule: true,
  default: 'Svg',
  Circle: 'Circle',
  Path: 'Path',
}));
jest.mock('react-native-safe-area-context', () => ({
  SafeAreaProvider: 'SafeAreaProvider',
  SafeAreaView: 'SafeAreaView',
}));
let saved: Snapshot;
let mockPermission = { location: true, notifications: true };
const snapshot = () => JSON.parse(JSON.stringify(saved));
NativeModules.AzkarDevice = {
  load: jest.fn(async () => snapshot()),
  permissions: jest.fn(async () => mockPermission),
  activate: jest.fn(async () => snapshot()),
  increment: jest.fn(async (period: 'morning' | 'evening', order: number) => {
    const current = saved[period][order] ?? 0;
    saved[period][order] = Math.min(
      document[period][order - 1].repetition,
      current + 1,
    );
    return snapshot();
  }),
  setLight: jest.fn(async light => {
    saved.light = light;
    return snapshot();
  }),
  reset: jest.fn(async () => {
    saved.morning = {};
    saved.evening = {};
    return snapshot();
  }),
};
const App = require('../src/App').default;
let tree: renderer.ReactTestRenderer;
const flush = async () => {
  await act(async () => {
    await Promise.resolve();
    await Promise.resolve();
  });
};
const press = async (testID: string) => {
  await act(async () => {
    tree.root.findByProps({ testID }).props.onPress();
  });
  await flush();
};
beforeEach(() => {
  jest.useFakeTimers();
  jest.clearAllMocks();
  saved = { morning: {}, evening: {}, light: false, nextFajr: null };
  mockPermission = { location: true, notifications: true };
});
afterEach(() => {
  if (tree) act(() => tree.unmount());
  jest.useRealTimers();
});
async function mount() {
  await act(async () => {
    tree = renderer.create(<App />);
  });
  await flush();
}
test('card tap and counter advance, periods save independent counts, final count caps', async () => {
  await mount();
  await press('reading-card');
  expect(saved.morning[1]).toBe(1);
  expect(
    tree.root.findByProps({ testID: 'counter' }).props.accessibilityLabel,
  ).toBe('عداد الذكر: 0 من 1');
  await press('period-evening');
  await press('counter');
  expect(saved.evening[1]).toBe(1);
  await press('period-morning');
  await press('counter');
  expect(saved.morning[1]).toBe(1);
});
test('theme survives reopening and reset requires confirmation, preserving theme', async () => {
  await mount();
  await press('theme-toggle');
  expect(saved.light).toBe(true);
  await press('reading-card');
  await press('reset');
  expect(saved.morning[1]).toBe(1);
  expect(tree.root.findByProps({ testID: 'dialog-title' }).props.children).toBe(
    'إعادة ضبط العدادات',
  );
  await press('dialog-action-1');
  expect(saved.morning).toEqual({});
  expect(saved.light).toBe(true);
  act(() => tree.unmount());
  await mount();
  expect(
    tree.root.findByProps({ testID: 'theme-toggle' }).props.accessibilityLabel,
  ).toBe('تفعيل الوضع الداكن');
});
test('permission setup explains reminders without exposing coordinates or prayer times', async () => {
  mockPermission = { location: false, notifications: false };
  await mount();
  expect(tree.root.findByProps({ testID: 'dialog-title' }).props.children).toBe(
    'تفعيل التذكيرات',
  );
  expect(tree.root.findByProps({ testID: 'reading-card' })).toBeTruthy();
  await press('counter');
  expect(saved.morning[1]).toBe(1);
});

test('vertical drag inside the reading card does not increment the dhikr', async () => {
  await mount();
  const card = tree.root.findByProps({ testID: 'reading-card' });
  await act(async () => {
    card.props.onTouchStart({ nativeEvent: { pageX: 100, pageY: 300 } });
    card.props.onTouchMove({ nativeEvent: { pageX: 100, pageY: 150 } });
    card.props.onPress();
  });
  expect(saved.morning).toEqual({});
  expect(NativeModules.AzkarDevice.increment).not.toHaveBeenCalled();
  await act(async () => {
    card.props.onTouchStart({ nativeEvent: { pageX: 100, pageY: 300 } });
    card.props.onPress();
  });
  expect(saved.morning[1]).toBe(1);
});

function completeCounts(period: 'morning' | 'evening') {
  return Object.fromEntries(
    document[period].map(item => [String(item.order), item.repetition]),
  );
}

test.each(['morning', 'evening'] as const)(
  '%s completion marks only its tab and shows the dialog once, even when the last unfinished dhikr is first',
  async period => {
    saved[period] = completeCounts(period);
    saved[period][1] -= 1;
    await mount();
    await press(`period-${period}`);
    expect(
      tree.root.findAllByProps({ testID: `complete-${period}` }),
    ).toHaveLength(0);
    await press('counter');
    expect(
      tree.root.findByProps({ testID: `complete-${period}` }).props.children,
    ).toBe('✓');
    const other = period === 'morning' ? 'evening' : 'morning';
    expect(
      tree.root.findAllByProps({ testID: `complete-${other}` }),
    ).toHaveLength(0);
    expect(
      tree.root.findByProps({ testID: 'dialog-title' }).props.children,
    ).toBe('تم ورد اليوم');
    await press('dialog-action-0');
    await press(`period-${other}`);
    await press(`period-${period}`);
    await press('counter');
    await press('theme-toggle');
    expect(tree.root.findAllByProps({ testID: 'dialog-title' })).toHaveLength(
      0,
    );
    act(() => tree.unmount());
    await mount();
    expect(
      tree.root.findByProps({ testID: `complete-${period}` }),
    ).toBeTruthy();
    expect(tree.root.findAllByProps({ testID: 'dialog-title' })).toHaveLength(
      0,
    );
  },
);

test('completing one dhikr does not finish a period with another incomplete count', async () => {
  saved.morning = completeCounts('morning');
  saved.morning[1] -= 1;
  saved.morning[2] -= 1;
  await mount();
  await press('counter');
  expect(tree.root.findAllByProps({ testID: 'complete-morning' })).toHaveLength(
    0,
  );
  expect(tree.root.findAllByProps({ testID: 'dialog-title' })).toHaveLength(0);
  await press('reading-card');
  expect(tree.root.findByProps({ testID: 'complete-morning' })).toBeTruthy();
  expect(tree.root.findByProps({ testID: 'dialog-title' }).props.children).toBe(
    'تم ورد اليوم',
  );
});

test('manual reset clears both completion marks and allows completing a period again', async () => {
  saved.morning = completeCounts('morning');
  saved.evening = completeCounts('evening');
  await mount();
  await press('reset');
  await press('dialog-action-0');
  expect(tree.root.findByProps({ testID: 'complete-morning' })).toBeTruthy();
  expect(tree.root.findByProps({ testID: 'complete-evening' })).toBeTruthy();
  await press('reset');
  await press('dialog-action-1');
  expect(tree.root.findAllByProps({ testID: 'complete-morning' })).toHaveLength(
    0,
  );
  expect(tree.root.findAllByProps({ testID: 'complete-evening' })).toHaveLength(
    0,
  );
  saved.morning = completeCounts('morning');
  saved.morning[1] -= 1;
  await press('theme-toggle');
  await press('counter');
  expect(tree.root.findByProps({ testID: 'dialog-title' }).props.children).toBe(
    'تم ورد اليوم',
  );
});

test('daily reset refreshed on resume clears both completion marks', async () => {
  const listener = jest.mocked(AppState.addEventListener);
  saved.morning = completeCounts('morning');
  saved.evening = completeCounts('evening');
  await mount();
  expect(tree.root.findByProps({ testID: 'complete-morning' })).toBeTruthy();
  expect(tree.root.findByProps({ testID: 'complete-evening' })).toBeTruthy();
  saved.morning = {};
  saved.evening = {};
  const onChange = listener.mock.calls.find(
    ([event]) => event === 'change',
  )![1];
  await act(async () => onChange('active'));
  await flush();
  expect(tree.root.findAllByProps({ testID: 'complete-morning' })).toHaveLength(
    0,
  );
  expect(tree.root.findAllByProps({ testID: 'complete-evening' })).toHaveLength(
    0,
  );
  expect(tree.root.findAllByProps({ testID: 'dialog-title' })).toHaveLength(0);
});

test('failed final increment does not mark the period complete', async () => {
  saved.morning = completeCounts('morning');
  saved.morning[1] -= 1;
  NativeModules.AzkarDevice.increment.mockRejectedValueOnce(
    new Error('save failed'),
  );
  await mount();
  await press('counter');
  expect(tree.root.findAllByProps({ testID: 'complete-morning' })).toHaveLength(
    0,
  );
  expect(tree.root.findByProps({ testID: 'dialog-title' }).props.children).toBe(
    'تعذر حفظ التغيير',
  );
});
