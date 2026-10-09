import data from '../assets/data/adhkar_morning_evening.json';
export type Period = 'morning' | 'evening';
export type Dhikr = { order: number; text: string; repetition: number };
export type Counts = Record<string, number>;
export type Snapshot = {
  morning: Counts;
  evening: Counts;
  light: boolean;
  nextFajr: number | null;
};
export const document: Record<Period, Dhikr[]> = data;
export const arabic = (n: number) =>
  String(n).replace(/[0-9]/g, d => '٠١٢٣٤٥٦٧٨٩'[Number(d)]);
export const fontSize = (text: string) =>
  text.length > 500 ? 23 : text.length > 330 ? 25 : text.length > 180 ? 28 : 32;
export const targetPage = (index: number, dx: number, total: number) =>
  Math.abs(dx) < 50
    ? index
    : Math.max(0, Math.min(total - 1, index + (dx > 0 ? 1 : -1)));
export const colors = {
  dark: {
    background: '#071224',
    top: '#11233A',
    bottom: '#040810',
    surface: '#11233A',
    card: '#142640',
    accent: '#D8A64B',
    text: '#F8F1E2',
    muted: '#97A5B8',
    border: '#D8A64B33',
    shadow: '#000000',
    selected: '#142640',
    onSelected: '#F8F1E2',
  },
  light: {
    background: '#F7F2E7',
    top: '#FFFCF5',
    bottom: '#EDE5D3',
    surface: '#F1EAD9',
    card: '#FFFDF7',
    accent: '#946B21',
    text: '#183E35',
    muted: '#657267',
    border: '#B58B4066',
    shadow: '#183E35',
    selected: '#234F43',
    onSelected: '#FFF4D9',
  },
};
