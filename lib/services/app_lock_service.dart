import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'storage_service.dart';

class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isUnlocked = false;
  bool _isAuthenticating = false;

  bool get isUnlocked => _isUnlocked;

  Future<bool> authenticate({
    String reason = 'Please authenticate to access Server Commander SSH',
    bool force = false,
  }) async {
    if (!force) {
      final enabled = await StorageService().isAppLockEnabled();
      if (!enabled) {
        _isUnlocked = true;
        return true;
      }
    }

    if (_isUnlocked || _isAuthenticating) return _isUnlocked;
    _isAuthenticating = true;

    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        _isUnlocked = true;
        _isAuthenticating = false;
        return true;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      _isUnlocked = didAuthenticate;
      _isAuthenticating = false;
      return didAuthenticate;
    } on PlatformException catch (_) {
      _isAuthenticating = false;
      return false;
    }
  }

  Future<void> lock() async {
    final enabled = await StorageService().isAppLockEnabled();
    if (enabled) {
      _isUnlocked = false;
    }
  }
}
