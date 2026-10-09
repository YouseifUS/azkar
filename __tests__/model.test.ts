import { arabic, document, fontSize, targetPage } from '../src/model';
import fs from 'fs';
import path from 'path';

test('every reviewed Flutter dhikr is preserved byte for byte', () => {
  const source = path.join(
    __dirname,
    '../legacy/flutter/assets/data/adhkar_morning_evening.json',
  );
  const bundled = fs.readFileSync(
    path.join(__dirname, '../assets/data/adhkar_morning_evening.json'),
  );
  expect(
    fs
      .readFileSync(
        path.join(
          __dirname,
          '../android/app/src/main/assets/adhkar_morning_evening.json',
        ),
      )
      .equals(bundled),
  ).toBe(true);
  if (fs.existsSync(source))
    expect(fs.readFileSync(source).equals(bundled)).toBe(true);
  for (const period of ['morning', 'evening'] as const) {
    expect(document[period]).toHaveLength(23);
    document[period].forEach((item, index) => {
      expect(item.order).toBe(index + 1);
      expect(item.text.trim()).not.toBe('');
      expect(item.repetition).toBeGreaterThan(0);
    });
  }
});
test('RTL horizontal navigation preserves boundaries and ignores small drags', () => {
  expect(targetPage(0, 100, 23)).toBe(1);
  expect(targetPage(10, -100, 23)).toBe(9);
  expect(targetPage(0, -100, 23)).toBe(0);
  expect(targetPage(22, 100, 23)).toBe(22);
  expect(targetPage(10, 49, 23)).toBe(10);
});
test('Arabic digits and original typography sizes', () => {
  expect(arabic(1234567890)).toBe('١٢٣٤٥٦٧٨٩٠');
  expect([1, 181, 331, 501].map(size => fontSize('ا'.repeat(size)))).toEqual([
    32, 28, 25, 23,
  ]);
});
