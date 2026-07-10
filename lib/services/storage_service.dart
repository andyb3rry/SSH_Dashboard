import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_profile.dart';

class StorageService {
  static const String _profilesKey = 'server_profiles_list';
  static const String _activeServerIdKey = 'active_server_id';
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<List<ServerProfile>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_profilesKey) ?? [];
    
    final profiles = <ServerProfile>[];
    bool needsSanitizeMigration = false;

    for (final str in jsonList) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        var profile = ServerProfile.fromJson(map);
        
        // Leggiamo i dati sensibili da KeyStore (Android) o Keychain (iOS)
        final securePwd = await _secureStorage.read(key: 'secret_pwd_${profile.id}');
        final secureKey = await _secureStorage.read(key: 'secret_key_${profile.id}');
        final secureCfSecret = await _secureStorage.read(key: 'cf_secret_${profile.id}');
        
        String finalPwd = securePwd ?? profile.password;
        String finalKey = secureKey ?? profile.privateKey;
        String finalCfSecret = secureCfSecret ?? profile.cloudflareClientSecret;
        
        // Migrazione trasparente: se troviamo password, chiave privata o client secret nel vecchio JSON su SharedPreferences,
        // le salviamo subito in KeyStore/Keychain e segniamo che SharedPreferences va ripulito dai segreti.
        if (securePwd == null && profile.password.isNotEmpty) {
          await _secureStorage.write(key: 'secret_pwd_${profile.id}', value: profile.password);
          needsSanitizeMigration = true;
        }
        if (secureKey == null && profile.privateKey.isNotEmpty) {
          await _secureStorage.write(key: 'secret_key_${profile.id}', value: profile.privateKey);
          needsSanitizeMigration = true;
        }
        if (secureCfSecret == null && profile.cloudflareClientSecret.isNotEmpty) {
          await _secureStorage.write(key: 'cf_secret_${profile.id}', value: profile.cloudflareClientSecret);
          needsSanitizeMigration = true;
        }
        if (profile.password.isNotEmpty || profile.privateKey.isNotEmpty || profile.cloudflareClientSecret.isNotEmpty) {
          needsSanitizeMigration = true;
        }

        profiles.add(profile.copyWith(password: finalPwd, privateKey: finalKey, cloudflareClientSecret: finalCfSecret));
      } catch (e) {
        // Ignora eventuali profili corrotti
      }
    }

    if (needsSanitizeMigration) {
      await _saveAll(profiles);
    }

    return profiles;
  }

  Future<void> saveProfile(ServerProfile profile) async {
    // 1. Scriviamo immediatamente password, privateKey e cloudflareClientSecret in memoria sicura (KeyStore / Keychain)
    if (profile.password.isNotEmpty) {
      await _secureStorage.write(key: 'secret_pwd_${profile.id}', value: profile.password);
    } else {
      await _secureStorage.delete(key: 'secret_pwd_${profile.id}');
    }
    if (profile.privateKey.isNotEmpty) {
      await _secureStorage.write(key: 'secret_key_${profile.id}', value: profile.privateKey);
    } else {
      await _secureStorage.delete(key: 'secret_key_${profile.id}');
    }
    if (profile.cloudflareClientSecret.isNotEmpty) {
      await _secureStorage.write(key: 'cf_secret_${profile.id}', value: profile.cloudflareClientSecret);
    } else {
      await _secureStorage.delete(key: 'cf_secret_${profile.id}');
    }

    // 2. Manteniamo la lista dei profili salvando su SharedPreferences SOLO i metadati non sensibili
    final profiles = await getProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await _saveAll(profiles);
  }

  Future<void> deleteProfile(String id) async {
    final profiles = await getProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveAll(profiles);

    // Rimuoviamo contestualmente i segreti associati da KeyStore / Keychain
    await _secureStorage.delete(key: 'secret_pwd_$id');
    await _secureStorage.delete(key: 'secret_key_$id');
    await _secureStorage.delete(key: 'cf_secret_$id');

    final activeId = await getActiveServerId();
    if (activeId == id) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeServerIdKey);
    }
  }

  Future<void> _saveAll(List<ServerProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    // Prima di salvare in SharedPreferences svuotiamo SEMPRE password, privateKey e cloudflareClientSecret
    final sanitizedList = profiles.map((p) => jsonEncode(p.copyWith(password: '', privateKey: '', cloudflareClientSecret: '').toJson())).toList();
    await prefs.setStringList(_profilesKey, sanitizedList);
  }

  Future<String?> getActiveServerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeServerIdKey);
  }

  Future<void> setActiveServerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeServerIdKey, id);
  }

  Future<String?> getHostFingerprint(String hostPortKey) async {
    return await _secureStorage.read(key: 'hostkey_$hostPortKey');
  }

  Future<void> saveHostFingerprint(String hostPortKey, String fingerprint) async {
    await _secureStorage.write(key: 'hostkey_$hostPortKey', value: fingerprint);
  }

  static const String _appLockEnabledKey = 'app_lock_biometric_enabled';
  static const String _terminalFontSizeKey = 'terminal_font_size';
  static const String _sshTimeoutKey = 'ssh_command_timeout_seconds';
  static const String _autoRefreshIntervalKey = 'auto_refresh_interval_seconds';

  Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appLockEnabledKey) ?? false;
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockEnabledKey, enabled);
  }

  Future<double> getTerminalFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_terminalFontSizeKey) ?? 14.0;
  }

  Future<void> setTerminalFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_terminalFontSizeKey, size);
  }

  Future<int> getSshTimeoutSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sshTimeoutKey) ?? 25;
  }

  Future<void> setSshTimeoutSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sshTimeoutKey, seconds);
  }

  Future<int> getAutoRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoRefreshIntervalKey) ?? 5;
  }

  Future<void> setAutoRefreshInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoRefreshIntervalKey, seconds);
  }

  Future<int> clearAllHostFingerprints() async {
    final allKeys = await _secureStorage.readAll();
    int count = 0;
    for (final key in allKeys.keys) {
      if (key.startsWith('hostkey_')) {
        await _secureStorage.delete(key: key);
        count++;
      }
    }
    return count;
  }
}
