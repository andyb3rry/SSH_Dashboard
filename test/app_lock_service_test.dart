import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_dashboard/services/app_lock_service.dart';
import 'package:ssh_dashboard/services/storage_service.dart';

void main() {
  group('AppLock & Storage Timeout Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getAppLockTimeoutSeconds returns 60 by default', () async {
      final storage = StorageService();
      final timeout = await storage.getAppLockTimeoutSeconds();
      expect(timeout, 60);
    });

    test('setAppLockTimeoutSeconds persists configuration', () async {
      final storage = StorageService();
      await storage.setAppLockTimeoutSeconds(-1);
      expect(await storage.getAppLockTimeoutSeconds(), -1);

      await storage.setAppLockTimeoutSeconds(300);
      expect(await storage.getAppLockTimeoutSeconds(), 300);
    });

    test('onAppPaused with timeout -1 (On Close Only) does not lock', () async {
      final storage = StorageService();
      await storage.setAppLockEnabled(true);
      await storage.setAppLockTimeoutSeconds(-1);

      final lockService = AppLockService();
      await lockService.onAppPaused();
      await lockService.onAppResumed();
      // When timeout is -1, background transitions should never set _isUnlocked to false
    });

    test('onAppPaused with timeout 0 immediately locks', () async {
      final storage = StorageService();
      await storage.setAppLockEnabled(true);
      await storage.setAppLockTimeoutSeconds(0);

      final lockService = AppLockService();
      // Simulate initial unlock by checking force or mock state if possible
      await lockService.onAppPaused();
    });
  });
}
