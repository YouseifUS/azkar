import React from 'react';
import renderer, { act } from 'react-test-renderer';
import { NativeModules } from 'react-native';
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
