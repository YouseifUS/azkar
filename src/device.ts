import { NativeModules, PermissionsAndroid, Platform } from 'react-native';
import type { Period, Snapshot } from './model';
export type PermissionState = { location: boolean; notifications: boolean };
export interface DeviceBridge {
  load(): Promise<Snapshot>;
  increment(period: Period, order: number): Promise<Snapshot>;
  setLight(light: boolean): Promise<Snapshot>;
  reset(): Promise<Snapshot>;
  permissions(): Promise<PermissionState>;
  activate(): Promise<Snapshot>;
}
export const device: DeviceBridge = NativeModules.AzkarDevice;
export async function requestPermissions() {
  if (Platform.OS === 'android' && Number(Platform.Version) >= 33) {
    await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
    );
  }
  await PermissionsAndroid.requestMultiple([
    PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION,
    PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
  ]);
}
