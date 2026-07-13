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
      final storage = StorageService();
      final enabled = await storage.isAppLockEnabled();
      if (!enabled) {
        _isUnlocked = true;
        _pausedAt = null;
        await storage.clearPausedAtTimestamp();
        return true;
      }
      if (_isAuthenticating) return _isUnlocked;

      final timeout = await storage.getAppLockTimeoutSeconds();
      if (timeout > 0) {
        DateTime? pauseTime = _pausedAt;
        if (pauseTime == null) {
          final savedEpoch = await storage.getPausedAtTimestamp();
          if (savedEpoch != null) {
            pauseTime = DateTime.fromMillisecondsSinceEpoch(savedEpoch);
          }
        }

        if (pauseTime != null) {
          final elapsed = DateTime.now().difference(pauseTime).inSeconds;
          _pausedAt = null;
          await storage.clearPausedAtTimestamp();
          if (elapsed < timeout) {
            _isUnlocked = true;
            return true;
          } else {
            _isUnlocked = false;
          }
        } else if (_isUnlocked) {
          return true;
        }
      } else if (timeout == -1) {
        if (_isUnlocked) {
          return true;
        }
      } else if (timeout == 0) {
        if (_isUnlocked) {
          final savedEpoch = await storage.getPausedAtTimestamp();
          if (savedEpoch != null) {
            _isUnlocked = false;
            _pausedAt = null;
            await storage.clearPausedAtTimestamp();
          } else {
            return true;
          }
        }
      }
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
        _pausedAt = null;
        await StorageService().clearPausedAtTimestamp();
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
      if (didAuthenticate) {
        _pausedAt = null;
        await StorageService().clearPausedAtTimestamp();
      }
      return didAuthenticate;
    } on PlatformException catch (_) {
      _isAuthenticating = false;
      return false;
    }
  }

  Future<void> onAppPaused() async {
    if (_isAuthenticating || !_isUnlocked) return;
    
    final storage = StorageService();
    final enabled = await storage.isAppLockEnabled();
    if (!enabled) return;

    final timeout = await storage.getAppLockTimeoutSeconds();
    if (timeout == 0) {
      _isUnlocked = false;
      _pausedAt = null;
      // Persist a marker so we know there was a pause event
      await storage.savePausedAtTimestamp(DateTime.now().millisecondsSinceEpoch);
    } else if (timeout == -1) {
      _pausedAt = null;
      await storage.clearPausedAtTimestamp();
    } else {
      if (_pausedAt == null) {
        final savedEpoch = await storage.getPausedAtTimestamp();
        if (savedEpoch == null) {
          _pausedAt = DateTime.now();
          await storage.savePausedAtTimestamp(_pausedAt!.millisecondsSinceEpoch);
        } else {
          _pausedAt = DateTime.fromMillisecondsSinceEpoch(savedEpoch);
        }
      }
    }
  }

  Future<void> onAppResumed() async {
    if (_isAuthenticating) return;

    final storage = StorageService();
    final enabled = await storage.isAppLockEnabled();
    if (!enabled) {
      _isUnlocked = true;
      _pausedAt = null;
      await storage.clearPausedAtTimestamp();
      return;
    }

    final timeout = await storage.getAppLockTimeoutSeconds();
    if (timeout == -1) {
      _pausedAt = null;
      await storage.clearPausedAtTimestamp();
      return;
    }
    if (timeout == 0) {
      final savedEpoch = await storage.getPausedAtTimestamp();
      if (savedEpoch != null) {
        _isUnlocked = false;
        _pausedAt = null;
        await storage.clearPausedAtTimestamp();
      }
      return;
    }

    DateTime? pauseTime = _pausedAt;
    if (pauseTime == null) {
      final savedEpoch = await storage.getPausedAtTimestamp();
      if (savedEpoch != null) {
        pauseTime = DateTime.fromMillisecondsSinceEpoch(savedEpoch);
      }
    }

    if (pauseTime != null) {
      final elapsed = DateTime.now().difference(pauseTime).inSeconds;
      _pausedAt = null;
      await storage.clearPausedAtTimestamp();
      if (elapsed >= timeout) {
        _isUnlocked = false;
      } else {
        _isUnlocked = true;
      }
    }
  }

  Future<void> lock() async {
    final storage = StorageService();
    final enabled = await storage.isAppLockEnabled();
    if (!enabled) return;

    final timeout = await storage.getAppLockTimeoutSeconds();
    if (timeout == -1 || timeout == 0) {
      _isUnlocked = false;
      _pausedAt = null;
      await storage.clearPausedAtTimestamp();
    } else {
      if (_pausedAt == null) {
        final savedEpoch = await storage.getPausedAtTimestamp();
        if (savedEpoch == null) {
          _pausedAt = DateTime.now();
          await storage.savePausedAtTimestamp(_pausedAt!.millisecondsSinceEpoch);
        } else {
          _pausedAt = DateTime.fromMillisecondsSinceEpoch(savedEpoch);
        }
      }
    }
  }
}
