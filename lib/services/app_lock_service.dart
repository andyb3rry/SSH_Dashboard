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
  DateTime? _pausedAt;

  bool get isUnlocked => _isUnlocked;
  bool get isAuthenticating => _isAuthenticating;

  Future<bool> authenticate({
    String reason = 'Please authenticate to access SSH Dashboard',
    bool force = false,
  }) async {
    if (!force) {
      final enabled = await StorageService().isAppLockEnabled();
      if (!enabled) {
        _isUnlocked = true;
        return true;
      }
      if (_isUnlocked || _isAuthenticating) return _isUnlocked;
    } else {
      if (_isAuthenticating) return false;
    }
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

  Future<void> onAppPaused() async {
    if (_isAuthenticating || !_isUnlocked) return;
    
    final enabled = await StorageService().isAppLockEnabled();
    if (!enabled) return;

    final timeout = await StorageService().getAppLockTimeoutSeconds();
    if (timeout == 0) {
      _isUnlocked = false;
      _pausedAt = null;
    } else if (timeout == -1) {
      _pausedAt = null;
    } else {
      _pausedAt = DateTime.now();
    }
  }

  Future<void> onAppResumed() async {
    if (_isAuthenticating || !_isUnlocked) return;

    final enabled = await StorageService().isAppLockEnabled();
    if (!enabled) {
      _pausedAt = null;
      return;
    }

    final timeout = await StorageService().getAppLockTimeoutSeconds();
    if (timeout == -1 || timeout == 0) {
      _pausedAt = null;
      return;
    }

    if (_pausedAt != null) {
      final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
      if (elapsed >= timeout) {
        _isUnlocked = false;
      }
    }
  }

  Future<void> lock() async {
    final enabled = await StorageService().isAppLockEnabled();
    if (enabled) {
      _isUnlocked = false;
      _pausedAt = null;
    }
  }
}
