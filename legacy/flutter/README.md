# Archived Flutter implementation

This is the complete Flutter 1.1.2 implementation retained for reference and rollback. The active application is React Native at the repository root. Assets, original tests, and build configuration are preserved here.

To run: install Flutter, configure the Android SDK, then run `flutter pub get` and `flutter run` from this directory. Shared preferences and application ID are unchanged in React Native. Android requires the same signing certificate for an in-place update. Rollback to a smaller version code requires explicit Android downgrade tooling; do not uninstall if you need to preserve local data.
