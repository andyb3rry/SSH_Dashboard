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

  /// Checks if the lock timeout has expired by reading the persisted paused-at timestamp.
  /// Returns true if the app should be locked (timeout expired).
  Future<bool> _hasTimeoutExpired() async {
    final storage = StorageService();
    final enabled = await storage.isAppLockEnabled();
    if (!enabled) return false;

    final timeout = await storage.getAppLockTimeoutSeconds();
    // -1 means "on close only", no time-based expiry
    if (timeout == -1) return false;
    // 0 means "immediately" — always expired when paused
    if (timeout == 0) {
      // Check if there was a pause event at all
      final savedEpoch = await storage.getPausedAtTimestamp();
      if (savedEpoch != null) {
        await storage.clearPausedAtTimestamp();
        return true;
      }
      return false;
    }

    // Read from memory first, then fall back to persisted value
    DateTime? pauseTime = _pausedAt;
    if (pauseTime == null) {
      final savedEpoch = await storage.getPausedAtTimestamp();
      if (savedEpoch != null) {
        pauseTime = DateTime.fromMillisecondsSinceEpoch(savedEpoch);
      }
    }

    if (pauseTime != null) {
      final elapsed = DateTime.now().difference(pauseTime).inSeconds;
      await storage.clearPausedAtTimestamp();
      _pausedAt = null;
      if (elapsed >= timeout) {
        return true;
      }
    }

    return false;
  }

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
      if (_isAuthenticating) return _isUnlocked;

      // Even if _isUnlocked is true, check if timeout has expired
      if (_isUnlocked) {
        final expired = await _hasTimeoutExpired();
        if (expired) {
          _isUnlocked = false;
        } else {
          return true;
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
      _pausedAt = DateTime.now();
      // Persist to disk so the timestamp survives process kills
      await storage.savePausedAtTimestamp(_pausedAt!.millisecondsSinceEpoch);
    }
  }

  Future<void> onAppResumed() async {
    if (_isAuthenticating) return;

    final storage = StorageService();
    final enabled = await storage.isAppLockEnabled();
    if (!enabled) {
      _pausedAt = null;
      await storage.clearPausedAtTimestamp();
      return;
    }

    // If not unlocked, nothing to check — authenticate() will be called separately
    if (!_isUnlocked) return;

    final timeout = await storage.getAppLockTimeoutSeconds();
    if (timeout == -1) {
      _pausedAt = null;
      await storage.clearPausedAtTimestamp();
      return;
    }
    if (timeout == 0) {
      // "Immediately" mode — check if there was a paused event
      final savedEpoch = await storage.getPausedAtTimestamp();
      if (savedEpoch != null) {
        _isUnlocked = false;
        _pausedAt = null;
        await storage.clearPausedAtTimestamp();
      }
      return;
    }

    // Read from memory first, then fall back to persisted value
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
      }
    }
  }

  Future<void> lock() async {
    final storage = StorageService();
    final enabled = await storage.isAppLockEnabled();
    if (enabled) {
      _isUnlocked = false;
      _pausedAt = null;
      await storage.clearPausedAtTimestamp();
    }
  }
}
