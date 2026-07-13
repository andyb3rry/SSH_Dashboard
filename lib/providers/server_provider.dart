import 'dart:async';
import 'package:flutter/widgets.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_userauth.dart';
import '../models/server_profile.dart';
import '../models/system_metrics.dart';
import '../models/docker_container.dart';
import '../models/process_info.dart';
import '../services/storage_service.dart';
import '../services/ssh_service.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class ServerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final StorageService _storageService = StorageService();
  final SshService _sshService = SshService();

  List<ServerProfile> _profiles = [];
  ServerProfile? _activeProfile;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _errorMessage = '';

  SystemMetrics _metrics = SystemMetrics.empty();
  List<DockerContainer> _containers = [];
  
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _isRefreshing = false;
  bool _isLoadingAction = false;

  /// Callback UI per richiedere autenticazione browser Cloudflare Access via GitHub OAuth se manca/scade il token
  Future<String?> Function(ServerProfile profile)? onCloudflareAuthCallback;

  ServerProvider() {
    WidgetsBinding.instance.addObserver(this);
    _sshService.onCloudflareAuthCallback = (profile) async {
      if (onCloudflareAuthCallback != null) {
        return await onCloudflareAuthCallback!(profile);
      }
      return null;
    };
  }

  List<ServerProfile> get profiles => _profiles;
  ServerProfile? get activeProfile => _activeProfile;
  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  String get errorMessage => _errorMessage;
  SystemMetrics get metrics => _metrics;
  List<DockerContainer> get containers => _containers;
  bool get isPolling => _isPolling;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingAction => _isLoadingAction;
  SshService get sshService => _sshService;

  Future<void> init() async {
    await loadProfiles();
    final activeId = await _storageService.getActiveServerId();
    if (activeId != null && _profiles.any((p) => p.id == activeId)) {
      _activeProfile = _profiles.firstWhere((p) => p.id == activeId);
      notifyListeners();
    }
  }

  Future<void> loadProfiles() async {
    _profiles = await _storageService.getProfiles();
    notifyListeners();
  }

  Future<void> saveProfile(ServerProfile profile) async {
    await _storageService.saveProfile(profile);
    await loadProfiles();
    if (_activeProfile?.id == profile.id) {
      _activeProfile = profile;
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String id) async {
    if (_activeProfile?.id == id) {
      await disconnect();
      _activeProfile = null;
    }
    await _storageService.deleteProfile(id);
    await loadProfiles();
  }

  Future<void> connect(ServerProfile profile) async {
    _status = ConnectionStatus.connecting;
    _errorMessage = '';
    _activeProfile = profile;
    notifyListeners();

    try {
      await _sshService.connect(profile);
      await _storageService.setActiveServerId(profile.id);
      _status = ConnectionStatus.connected;
      notifyListeners();

      // Ricarica immediata dati e avvio polling
      await refreshData();
      startPolling();
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    stopPolling();
    await _sshService.disconnect();
    _status = ConnectionStatus.disconnected;
    _metrics = SystemMetrics.empty();
    _containers = [];
    notifyListeners();
  }

  void startPolling({int intervalSeconds = 4}) {
    stopPolling();
    _isPolling = true;
    _pollTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      if (_status == ConnectionStatus.connected && !_isRefreshing) {
        refreshData(silent: true);
      }
    });
    notifyListeners();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    notifyListeners();
  }

  void togglePolling() {
    if (_isPolling) {
      stopPolling();
    } else {
      startPolling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _status == ConnectionStatus.connected && _activeProfile != null) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    if (_status != ConnectionStatus.connected || _activeProfile == null) return;
    try {
      await refreshData(silent: true);
      if (_metrics.uptimeString == 'Unknown' || !_sshService.isConnected) {
        await _autoReconnect();
      }
    } catch (_) {
      await _autoReconnect();
    }
  }

  Future<void> _autoReconnect() async {
    if (_activeProfile == null) return;
    try {
      await _sshService.disconnect();
      await _sshService.connect(_activeProfile!);
      await refreshData(silent: true);
      startPolling();
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = 'Connection dropped during standby: ${e.toString().replaceAll('Exception: ', '')}';
      notifyListeners();
    }
  }

  Future<void> refreshData({bool silent = false}) async {
    if (_status != ConnectionStatus.connected || _isRefreshing) return;
    if (silent && _sshService.isBusyWithCommand) return;
    _isRefreshing = true;
    if (!silent) notifyListeners();

    try {
      if (!_sshService.isConnected && _activeProfile != null) {
        await _sshService.connect(_activeProfile!);
      }
      final newMetrics = await _sshService.fetchSystemMetrics();
      if (newMetrics.uptimeString == 'Unknown' && _activeProfile != null) {
        await _sshService.disconnect();
        await _sshService.connect(_activeProfile!);
        final retryMetrics = await _sshService.fetchSystemMetrics();
        if (retryMetrics.uptimeString != 'Unknown') {
          _metrics = retryMetrics;
          _containers = await _sshService.fetchDockerContainers();
          return;
        } else {
          throw Exception('SSH connection interrupted or dropped.');
        }
      }

      final newContainers = await _sshService.fetchDockerContainers();
      _metrics = newMetrics;
      _containers = newContainers;
    } catch (e) {
      if (!silent) {
        _errorMessage = 'Reload error: $e';
      }
      if (!_sshService.isConnected) {
        _status = ConnectionStatus.error;
        _errorMessage = 'Connection dropped: ${e.toString().replaceAll('Exception: ', '')}';
        stopPolling();
      }
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  // Docker actions
  Future<bool> startContainer(String id) async {
    _isLoadingAction = true;
    notifyListeners();
    try {
      await _sshService.startContainer(id);
      await refreshData(silent: true);
      return true;
    } catch (e) {
      _errorMessage = 'Unable to start container: $e';
      return false;
    } finally {
      _isLoadingAction = false;
      notifyListeners();
    }
  }

  Future<bool> stopContainer(String id) async {
    _isLoadingAction = true;
    notifyListeners();
    try {
      await _sshService.stopContainer(id);
      await refreshData(silent: true);
      return true;
    } catch (e) {
      _errorMessage = 'Unable to stop container: $e';
      return false;
    } finally {
      _isLoadingAction = false;
      notifyListeners();
    }
  }

  Future<bool> restartContainer(String id) async {
    _isLoadingAction = true;
    notifyListeners();
    try {
      await _sshService.restartContainer(id);
      await refreshData(silent: true);
      return true;
    } catch (e) {
      _errorMessage = 'Unable to restart container: $e';
      return false;
    } finally {
      _isLoadingAction = false;
      notifyListeners();
    }
  }

  Future<String> getContainerLogs(String id) async {
    try {
      return await _sshService.fetchContainerLogs(id);
    } catch (e) {
      return 'Error retrieving logs: $e';
    }
  }

  void setOnUserInfoRequestCallback(Future<List<String>?> Function(SSHUserInfoRequest request)? callback) {
    _sshService.onUserInfoRequestCallback = callback;
  }

  // Power actions
  Future<void> rebootServer([String? sudoPassword]) async {
    stopPolling();
    try {
      await _sshService.rebootServer(sudoPassword);
    } catch (_) {}
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<void> shutdownServer([String? sudoPassword]) async {
    stopPolling();
    try {
      await _sshService.shutdownServer(sudoPassword);
    } catch (_) {}
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<String> executeCommand(String command, {Duration timeout = const Duration(seconds: 25)}) async {
    if (!_sshService.isConnected && _activeProfile != null) {
      await _sshService.connect(_activeProfile!);
    }
    try {
      return await _sshService.executeCommand(command, timeout: timeout);
    } catch (e) {
      if (_activeProfile != null && (e.toString().contains('not connected') || e.toString().contains('closed') || e.toString().contains('Broken pipe') || e.toString().contains('Socket'))) {
        await _sshService.connect(_activeProfile!);
        return await _sshService.executeCommand(command, timeout: timeout);
      }
      rethrow;
    }
  }

  Future<String> executeSudoCommand(String command, String sudoPassword, {Duration timeout = const Duration(seconds: 25)}) async {
    if (!_sshService.isConnected && _activeProfile != null) {
      await _sshService.connect(_activeProfile!);
    }
    try {
      return await _sshService.executeSudoCommand(command, sudoPassword, timeout: timeout);
    } catch (e) {
      if (_activeProfile != null && (e.toString().contains('not connected') || e.toString().contains('closed') || e.toString().contains('Broken pipe') || e.toString().contains('Socket'))) {
        await _sshService.connect(_activeProfile!);
        return await _sshService.executeSudoCommand(command, sudoPassword, timeout: timeout);
      }
      rethrow;
    }
  }

  Future<String> executeSudoCommandStreamed(
    String command,
    String sudoPassword, {
    Duration timeout = const Duration(minutes: 10),
    void Function(String chunk)? onStdout,
    void Function(String chunk)? onStderr,
  }) async {
    if (!_sshService.isConnected && _activeProfile != null) {
      await _sshService.connect(_activeProfile!);
    }
    try {
      return await _sshService.executeSudoCommandStreamed(
        command,
        sudoPassword,
        timeout: timeout,
        onStdout: onStdout,
        onStderr: onStderr,
      );
    } catch (e) {
      if (_activeProfile != null && (e.toString().contains('not connected') || e.toString().contains('closed') || e.toString().contains('Broken pipe') || e.toString().contains('Socket'))) {
        await _sshService.connect(_activeProfile!);
        return await _sshService.executeSudoCommandStreamed(
          command,
          sudoPassword,
          timeout: timeout,
          onStdout: onStdout,
          onStderr: onStderr,
        );
      }
      rethrow;
    }
  }

  Future<List<ProcessInfo>> fetchRunningProcesses() async {
    if (_status != ConnectionStatus.connected) return [];
    return await _sshService.fetchRunningProcesses();
  }

  Future<void> sendSignalToProcess(int pid, int signal, [String? sudoPassword]) async {
    if (_status != ConnectionStatus.connected) throw Exception('Not connected to server.');
    await _sshService.sendSignalToProcess(pid, signal, sudoPassword);
    await refreshData(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopPolling();
    _sshService.disconnect();
    super.dispose();
  }
}
