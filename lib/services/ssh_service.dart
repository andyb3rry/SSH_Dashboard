import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'storage_service.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_userauth.dart';
import '../models/server_profile.dart';
import '../models/system_metrics.dart';
import '../models/docker_container.dart';
import '../models/disk_info.dart';
import '../models/process_info.dart';

class CloudflareWebSocketSocket implements SSHSocket {
  final WebSocket _webSocket;
  final StreamController<Uint8List> _streamController = StreamController<Uint8List>();
  final StreamController<List<int>> _sinkController = StreamController<List<int>>();

  CloudflareWebSocketSocket(this._webSocket) {
    _webSocket.pingInterval = const Duration(seconds: 15);
    _webSocket.listen(
      (data) {
        if (data is Uint8List) {
          _streamController.add(data);
        } else if (data is List<int>) {
          _streamController.add(Uint8List.fromList(data));
        } else if (data is String) {
          _streamController.add(Uint8List.fromList(data.codeUnits));
        }
      },
      onError: (err) {
        _streamController.addError(err);
      },
      onDone: () {
        if (_webSocket.closeCode != null && _webSocket.closeCode != 1000) {
          _streamController.addError(
            Exception(
              'The WebSocket channel to Cloudflare closed during SSH handshake (Close code ${_webSocket.closeCode}: ${_webSocket.closeReason ?? "Abnormal closure/Timeout"}).\n'
              'Check cloudflared container logs to see if access to port 22 of the target server IP was interrupted by a timeout or policy.'
            )
          );
        }
        _streamController.close();
      },
    );

    _sinkController.stream.listen((data) {
      if (_webSocket.readyState == WebSocket.open) {
        _webSocket.add(data);
      }
    });
  }

  static Future<CloudflareWebSocketSocket> connect(
    String host,
    int port, {
    String? clientId,
    String? clientSecret,
  }) async {
    String inputHost = host.trim();
    if (inputHost.startsWith('https://')) {
      inputHost = inputHost.substring(8);
    } else if (inputHost.startsWith('http://')) {
      inputHost = inputHost.substring(7);
    } else if (inputHost.startsWith('wss://')) {
      inputHost = inputHost.substring(6);
    } else if (inputHost.startsWith('ws://')) {
      inputHost = inputHost.substring(5);
    }

    String hostPart = inputHost;
    String pathPart = '';
    
    final slashIdx = inputHost.indexOf('/');
    if (slashIdx != -1) {
      hostPart = inputHost.substring(0, slashIdx);
      pathPart = inputHost.substring(slashIdx);
    }
    if (hostPart.contains(':')) {
      hostPart = hostPart.split(':')[0];
    }

    final effectivePort = (port <= 0 || port == 80 || port == 443) ? 443 : port;
    final String uriStr;
    if (pathPart.isEmpty || pathPart == '/') {
      uriStr = (effectivePort == 443)
          ? 'wss://$hostPart/'
          : 'wss://$hostPart:$effectivePort/';
    } else {
      uriStr = (effectivePort == 443)
          ? 'wss://$hostPart$pathPart'
          : 'wss://$hostPart:$effectivePort$pathPart';
    }
        
    final httpUri = Uri.parse(uriStr.replaceAll(RegExp(r'^wss?:'), 'https:'));
    // [C2] Explicit TLS certificate validation — reject all bad certificates
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => false;
    try {
      final req = await client.getUrl(httpUri);
      req.headers.set('User-Agent', 'cloudflared/2025.1.0 (dartssh2)');
      req.headers.set('Origin', 'https://$hostPart');
      req.headers.set('Host', hostPart);

      final id = clientId?.trim() ?? '';
      final secret = clientSecret?.trim() ?? '';

      if (id.isNotEmpty && secret.isNotEmpty) {
        req.headers.set('CF-Access-Client-Id', id);
        req.headers.set('CF-Access-Client-Secret', secret);
      }

      final rng = Random.secure();
      final key = base64Encode(List<int>.generate(16, (_) => rng.nextInt(256)));
      req.headers.set('Connection', 'Upgrade');
      req.headers.set('Upgrade', 'websocket');
      req.headers.set('Sec-WebSocket-Version', '13');
      req.headers.set('Sec-WebSocket-Key', key);
      req.headers.set('Sec-WebSocket-Protocol', 'access, cloudflared, ssh');

      final resp = await req.close();

      if (resp.statusCode == 101 ||
          (resp.headers.value('upgrade')?.toLowerCase() == 'websocket' && resp.headers.value('sec-websocket-accept') != null)) {
        final rawSocket = await resp.detachSocket();
        final ws = WebSocket.fromUpgradedSocket(
          rawSocket,
          serverSide: false,
        );
        return CloudflareWebSocketSocket(ws);
      } else {
        // [M6] Read body for detection but don't leak full headers/body in exceptions
        final bodyBytes = await resp.cast<List<int>>().expand((x) => x).take(350).toList();
        final bodyText = utf8.decode(bodyBytes, allowMalformed: true).trim();
        client.close();

        if (bodyText.contains('Sign in') && bodyText.contains('Cloudflare Access') || bodyText.contains('<title>Sign in')) {
          throw Exception(
            'Cloudflare Zero Trust intercepted the connection and returned a Web Login page.\n\n'
            'The provided Service Token may have failed validation or may not have an active Policy on the Access application.\n\n'
            'HOW TO RESOLVE:\n'
            '1. Log into Cloudflare Zero Trust dashboard -> Access -> Applications.\n'
            '2. Check the Policies tab for your SSH application.\n'
            '3. Ensure there is a "Service Auth" policy that includes your Service Token.\n'
            '4. Verify that Client ID and Client Secret are typed accurately.'
          );
        }

        if (resp.statusCode == 403) {
          throw Exception(
            'Cloudflare Zero Trust denied access (HTTP 403 Forbidden).\n\n'
            'Ensure the Client ID and Client Secret are correct and authorized.'
          );
        } else if (resp.statusCode == 302 || resp.statusCode == 301) {
          throw Exception(
            'Cloudflare Zero Trust requested a redirect (HTTP ${resp.statusCode}).\n\n'
            'Service Token authentication failed — the server is redirecting to web login.'
          );
        }

        // [M6] Sanitized error — do NOT leak raw response headers or body content
        throw Exception(
          'WebSocket connection to Cloudflare Tunnel failed (HTTP ${resp.statusCode} instead of 101 Switching Protocols).\n\n'
          'Check your Cloudflare Tunnel configuration, hostname, and Service Token credentials.'
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Cloudflare Access')) {
        rethrow;
      }
      rethrow;
    }
  }

  @override
  Stream<Uint8List> get stream => _streamController.stream;

  @override
  StreamSink<List<int>> get sink => _sinkController.sink;

  @override
  Future<void> get done => _webSocket.done;

  @override
  Future<void> close() async {
    await _webSocket.close();
    await _streamController.close();
    await _sinkController.close();
  }

  @override
  void destroy() {
    _webSocket.close();
    _streamController.close();
    _sinkController.close();
  }
}

class SshService {
  SSHClient? _client;
  ServerProfile? _currentProfile;
  bool _isBusyWithCommand = false;

  double _lastRxBytes = 0.0;
  double _lastTxBytes = 0.0;
  DateTime? _lastNetTimestamp;
  double? _lastCpuUsed;
  double? _lastCpuTotal;

  /// Callback per intercettare sfide interattive, OTP o link browser 2FA del server
  Future<List<String>?> Function(SSHUserInfoRequest request)? onUserInfoRequestCallback;

  /// [C1] Callback per verificare il fingerprint SSH del server alla prima connessione (TOFU)
  /// Riceve: host, tipo di chiave, fingerprint SHA-256 hex. Ritorna true per accettare.
  Future<bool> Function(String host, String keyType, String fingerprintHex)? onHostKeyVerifyCallback;

  /// Callback per richiedere inserimento Service Token Cloudflare Access se mancano i segreti
  Future<String?> Function(ServerProfile profile)? onCloudflareAuthCallback;

  bool get isConnected => _client != null && !_client!.isClosed;
  bool get isBusyWithCommand => _isBusyWithCommand;
  ServerProfile? get currentProfile => _currentProfile;

  void updateCurrentProfile(ServerProfile profile) {
    _currentProfile = profile;
  }

  Future<void> connect(ServerProfile profile) async {
    // Riutilizzo immediato dell'unica istanza persistente di SSHClient se già attiva per questo server
    if (isConnected && _currentProfile?.id == profile.id && _currentProfile?.host == profile.host) {
      return;
    }
    await disconnect();
    _currentProfile = profile;

    SSHSocket socket;
    if (profile.useCloudflareTunnel) {
      String clientId = profile.cloudflareClientId;
      String clientSecret = profile.cloudflareClientSecret;
      try {
        socket = await CloudflareWebSocketSocket.connect(
          profile.host,
          profile.port,
          clientId: clientId,
          clientSecret: clientSecret,
        );
      } catch (e) {
        if (onCloudflareAuthCallback != null && (clientId.isEmpty || clientSecret.isEmpty)) {
          final res = await onCloudflareAuthCallback!(profile);
          if (res != null && res.isNotEmpty) {
            final latestProfile = _currentProfile ?? profile;
            clientId = latestProfile.cloudflareClientId;
            clientSecret = latestProfile.cloudflareClientSecret;
            socket = await CloudflareWebSocketSocket.connect(
              latestProfile.host,
              latestProfile.port,
              clientId: clientId,
              clientSecret: clientSecret,
            );
          } else {
            throw Exception('Cloudflare Access Service Token credentials not provided or cancelled.');
          }
        } else {
          throw Exception('Cloudflare connection failed ($e). Check your Client ID and Client Secret Service Tokens.');
        }
      }
    } else {
      String cleanHost = profile.host.trim();
      cleanHost = cleanHost.replaceAll(RegExp(r'^(https?|wss?):\/\/'), '');
      if (cleanHost.contains('#')) cleanHost = cleanHost.split('#')[0];
      if (cleanHost.contains('/')) cleanHost = cleanHost.split('/')[0];
      if (cleanHost.contains(':')) cleanHost = cleanHost.split(':')[0];
      socket = await SSHSocket.connect(
        cleanHost,
        profile.port <= 0 ? 22 : profile.port,
        timeout: const Duration(seconds: 10),
      );
    }

    Future<List<String>?> userInfoHandler(SSHUserInfoRequest request) async {
      // Se è una richiesta standard di password via keyboard-interactive
      if (request.prompts.length == 1 &&
          request.prompts.first.promptText.toLowerCase().contains('password') &&
          profile.password.isNotEmpty) {
        return [profile.password];
      }
      // Altrimenti delegato alla callback UI (per sfide 2FA, OTP o link redirezione)
      if (onUserInfoRequestCallback != null) {
        return await onUserInfoRequestCallback!(request);
      }
      return null;
    }

    FutureOr<bool> hostKeyVerifier(String type, Uint8List fingerprint) async {
      // [C3] Compute SHA-256 fingerprint — hex for storage, base64 for display (matches ssh-keygen -l)
      final fpDigest = sha256.convert(fingerprint);
      final fpHash = fpDigest.toString();
      final fpBase64 = base64Encode(fpDigest.bytes).replaceAll(RegExp(r'=+$'), '');
      final storage = StorageService();
      final hostKeyId = '${profile.id}_${profile.host}_${profile.port}';
      final storedFp = await storage.getHostFingerprint(hostKeyId);
      if (storedFp == null) {
        // [C1] First connection — ask user for TOFU confirmation via callback
        if (onHostKeyVerifyCallback != null) {
          final accepted = await onHostKeyVerifyCallback!(profile.host, type, fpBase64);
          if (!accepted) {
            throw Exception('SSH host key rejected by user for ${profile.host}.');
          }
        }
        await storage.saveHostFingerprint(hostKeyId, fpHash);
        return true;
      }
      if (storedFp != fpHash) {
        throw Exception(
          '⚠️ SECURITY ALERT: SSH Host Key Mismatch (MITM Protection)!\n'
          'The host key fingerprint for ${profile.host} has changed.\n'
          'If the server was reinstalled, delete and re-add the server profile or clear host fingerprints in Settings.'
        );
      }
      return true;
    }

    if (profile.useAuthKey && profile.privateKey.isNotEmpty) {
      final identities = SSHKeyPair.fromPem(profile.privateKey);
      _client = SSHClient(
        socket,
        username: profile.username,
        identities: identities,
        onUserInfoRequest: userInfoHandler,
        onVerifyHostKey: hostKeyVerifier,
      );
    } else {
      _client = SSHClient(
        socket,
        username: profile.username,
        onPasswordRequest: () => profile.password,
        onUserInfoRequest: userInfoHandler,
        onVerifyHostKey: hostKeyVerifier,
      );
    }

    // Facciamo un check rapido del login
    await _client!.authenticated;
  }

  Future<void> disconnect() async {
    if (_client != null) {
      _client!.close();
      _client = null;
    }
    _currentProfile = null;
    _lastRxBytes = 0.0;
    _lastTxBytes = 0.0;
    _lastNetTimestamp = null;
    _lastCpuUsed = null;
    _lastCpuTotal = null;
  }

  Future<String> executeCommand(String command, {Duration timeout = const Duration(seconds: 25)}) async {
    if (!isConnected) {
      throw Exception('SSH client not connected.');
    }
    _isBusyWithCommand = true;
    try {
      final session = await _client!.execute(command).timeout(timeout);
      final outputBytes = await session.stdout.fold<List<int>>(<int>[], (prev, element) => prev..addAll(element));
      final errorBytes = await session.stderr.fold<List<int>>(<int>[], (prev, element) => prev..addAll(element));
      await session.done;

      final stdoutStr = utf8.decode(outputBytes, allowMalformed: true).trim();
      final stderrStr = utf8.decode(errorBytes, allowMalformed: true).trim();

      if (session.exitCode != 0 && stderrStr.isNotEmpty && stdoutStr.isEmpty) {
        throw Exception(stderrStr);
      }
      return stdoutStr;
    } catch (e) {
      // NON disconnettere per un semplice TimeoutException di un comando lungo!
      if (_client != null && (_client!.isClosed || e is SocketException || e.toString().contains('closed') || e.toString().contains('Broken pipe') || e.toString().contains('Connection reset'))) {
        await disconnect();
      }
      rethrow;
    } finally {
      _isBusyWithCommand = false;
    }
  }

  Future<SystemMetrics> fetchSystemMetrics() async {
    if (!isConnected) return SystemMetrics.empty();

    const script = '''
free -m | grep "Mem:" | awk '{print "MEM:", \$2, \$3}'
uptime -p 2>/dev/null | sed 's/^/UPTIME: /' || uptime | sed 's/^/UPTIME: /'
cat /proc/loadavg | awk '{print "LOAD:", \$1, \$2, \$3}'
echo "KERNEL: \$(uname -r)"
grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d'"' -f2 | sed 's/^/OS: /' || echo "OS: Linux"
awk -F':' '/^model name|^Processor|^Hardware/ {sub(/^[ \\t]+/, "", \$2); print "CPUMODEL: " \$2; exit}' /proc/cpuinfo 2>/dev/null || echo "CPUMODEL: Unknown Processor"
awk '/^cpu / {u=\$2+\$3+\$4+\$7+\$8+\$9; t=u+\$5+\$6; print "CPURAW:", u, t}' /proc/stat 2>/dev/null
cpu_val=\$( (awk '/^cpu / {u=\$2+\$3+\$4+\$7+\$8+\$9; t=u+\$5+\$6; print u, t}' /proc/stat; sleep 0.4; awk '/^cpu / {u=\$2+\$3+\$4+\$7+\$8+\$9; t=u+\$5+\$6; print u, t}' /proc/stat) 2>/dev/null | awk 'NR==1 {u1=\$1; t1=\$2} NR==2 {u2=\$1; t2=\$2; if(t2-t1>0) printf "%.1f", (u2-u1)*100/(t2-t1); else print "0.0"}' )
if [ -z "\$cpu_val" ]; then cpu_val="0.0"; fi
echo "CPU: \$cpu_val"
cpu_temp=""
for hw in /sys/class/hwmon/hwmon*; do
  if [ -f "\$hw/name" ]; then
    hw_name=\$(cat "\$hw/name" 2>/dev/null)
    if [ "\$hw_name" = "coretemp" ] || [ "\$hw_name" = "k10temp" ] || [ "\$hw_name" = "zenpower" ]; then
      for label in "\$hw"/temp*_label; do
        if [ -f "\$label" ] && grep -qi "package id 0\\|tctl\\|tdie" "\$label" 2>/dev/null; then
          idx=\$(echo "\$label" | sed 's/.*\\/temp\\([0-9][0-9]*\\)_label.*/\\1/')
          if [ -f "\$hw/temp\${idx}_input" ]; then
            cpu_temp=\$(cat "\$hw/temp\${idx}_input" 2>/dev/null)
            break 2
          fi
        fi
      done
      for inp in "\$hw"/temp1_input "\$hw"/temp*_input; do
        if [ -f "\$inp" ]; then
          cpu_temp=\$(cat "\$inp" 2>/dev/null)
          break 2
        fi
      done
    fi
  fi
done
if [ -z "\$cpu_temp" ] && command -v sensors >/dev/null 2>&1; then
  cpu_temp=\$(sensors -u 2>/dev/null | awk '/Package id 0:|Tctl:/ {getline; print int(\$2*1000); exit}')
fi
if [ -n "\$cpu_temp" ]; then
  echo "\$cpu_temp" | awk '{print "TEMP:", (\$1 > 1000 ? \$1/1000 : \$1)}'
elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
  awk '{print "TEMP:", (\$1 > 1000 ? \$1/1000 : \$1)}' /sys/class/thermal/thermal_zone0/temp
else
  t_val=\$(find /sys/class/hwmon/hwmon*/ -name "temp*_input" -exec cat {} + 2>/dev/null | head -n 1)
  if [ -n "\$t_val" ]; then
    echo "\$t_val" | awk '{print "TEMP:", (\$1 > 1000 ? \$1/1000 : \$1)}'
  else
    echo "TEMP: -1.0"
  fi
fi
awk 'NR>2 && !/lo:|docker|veth|br-/ {rx+=\$2; tx+=\$10} END {print "NET:", rx+0, tx+0}' /proc/net/dev
df -mP | awk 'NR>1 && (\$6 == "/" || \$6 ~ /^\\/mnt/) && !/tmpfs|cdrom|devtmpfs|udev|overlay|loop/ {print "DISK:", \$1, \$2, \$3, \$4, \$5, \$6}'
''';

    try {
      final output = await executeCommand(script, timeout: const Duration(seconds: 10));
      final lines = output.split('\n').map((l) => l.trim()).toList();

      double memTotal = 1.0;
      double memUsed = 0.0;
      String uptimeStr = 'Unknown';
      String loadAvg = '0.0, 0.0, 0.0';
      String kernel = 'Unknown';
      String osRelease = 'Linux OS';
      String cpuModel = 'Unknown Processor';
      double cpuPercentage = 0.0;
      double cpuTemp = -1.0;
      double rxKbps = 0.0;
      double txKbps = 0.0;
      final disksList = <DiskInfo>[];
      double rootDiskTotal = 1.0;
      double rootDiskUsed = 0.0;

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('MEM:')) {
          final parts = line.substring(4).trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            memTotal = double.tryParse(parts[0]) ?? 1.0;
            memUsed = double.tryParse(parts[1]) ?? 0.0;
          }
        } else if (line.startsWith('UPTIME:')) {
          uptimeStr = line.substring(7).trim().replaceAll('up ', '');
        } else if (line.startsWith('LOAD:')) {
          loadAvg = line.substring(5).trim().replaceAll(' ', ', ');
        } else if (line.startsWith('KERNEL:')) {
          kernel = line.substring(7).trim();
        } else if (line.startsWith('OS:')) {
          osRelease = line.substring(3).trim();
        } else if (line.startsWith('CPUMODEL:')) {
          cpuModel = line.substring(9).trim();
        } else if (line.startsWith('CPU:')) {
          if (_lastCpuTotal == null || _lastCpuUsed == null) {
            cpuPercentage = double.tryParse(line.substring(4).trim()) ?? 0.0;
          }
        } else if (line.startsWith('CPURAW:')) {
          final parts = line.substring(7).trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final currentUsed = double.tryParse(parts[0]) ?? 0.0;
            final currentTotal = double.tryParse(parts[1]) ?? 0.0;
            if (_lastCpuTotal != null && _lastCpuUsed != null && currentTotal > _lastCpuTotal!) {
              final totalDiff = currentTotal - _lastCpuTotal!;
              final usedDiff = currentUsed - _lastCpuUsed!;
              if (totalDiff > 0) {
                cpuPercentage = (usedDiff * 100.0 / totalDiff).clamp(0.0, 100.0);
              }
            }
            _lastCpuUsed = currentUsed;
            _lastCpuTotal = currentTotal;
          }
        } else if (line.startsWith('TEMP:')) {
          cpuTemp = double.tryParse(line.substring(5).trim()) ?? -1.0;
        } else if (line.startsWith('NET:')) {
          final parts = line.substring(4).trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final currentRx = double.tryParse(parts[0]) ?? 0.0;
            final currentTx = double.tryParse(parts[1]) ?? 0.0;
            final now = DateTime.now();
            if (_lastNetTimestamp != null && _lastRxBytes > 0 && currentRx >= _lastRxBytes) {
              final elapsedSec = now.difference(_lastNetTimestamp!).inMilliseconds / 1000.0;
              if (elapsedSec > 0) {
                rxKbps = ((currentRx - _lastRxBytes) / elapsedSec) / 1024.0;
                txKbps = ((currentTx - _lastTxBytes) / elapsedSec) / 1024.0;
              }
            }
            _lastRxBytes = currentRx;
            _lastTxBytes = currentTx;
            _lastNetTimestamp = now;
          }
        } else if (line.startsWith('DISK:')) {
          final parts = line.substring(5).trim().split(RegExp(r'\s+'));
          if (parts.length >= 6) {
            final fs = parts[0];
            final totalMb = double.tryParse(parts[1]) ?? 1.0;
            final usedMb = double.tryParse(parts[2]) ?? 0.0;
            final freeMb = double.tryParse(parts[3]) ?? 0.0;
            final pctStr = parts[4].replaceAll('%', '');
            final pct = double.tryParse(pctStr) ?? ((usedMb / (totalMb > 0 ? totalMb : 1.0)) * 100.0);
            final mount = parts.sublist(5).join(' ');

            if (mount == '/' || mount.startsWith('/mnt')) {
              final totalGb = totalMb / 1024.0;
              final usedGb = usedMb / 1024.0;
              final freeGb = freeMb / 1024.0;

              final diskInfo = DiskInfo(
                filesystem: fs,
                mountPoint: mount,
                totalGb: totalGb,
                usedGb: usedGb,
                freeGb: freeGb,
                usagePercentage: pct.clamp(0.0, 100.0),
              );
              disksList.add(diskInfo);

              if (mount == '/' || (rootDiskUsed == 0.0 && disksList.length == 1)) {
                rootDiskTotal = totalGb;
                rootDiskUsed = usedGb;
              }
            }
          }
        }
      }
      if (disksList.isEmpty) {
        disksList.add(DiskInfo(
          filesystem: '/dev/root',
          mountPoint: '/',
          totalGb: rootDiskTotal,
          usedGb: rootDiskUsed,
          freeGb: (rootDiskTotal - rootDiskUsed).clamp(0.0, rootDiskTotal),
          usagePercentage: ((rootDiskUsed / rootDiskTotal) * 100.0).clamp(0.0, 100.0),
        ));
      }

      return SystemMetrics(
        cpuUsagePercentage: cpuPercentage.clamp(0.0, 100.0),
        memoryUsedMb: memUsed,
        memoryTotalMb: memTotal > 0 ? memTotal : 1.0,
        diskUsedGb: rootDiskUsed,
        diskTotalGb: rootDiskTotal > 0 ? rootDiskTotal : 1.0,
        uptimeString: uptimeStr,
        loadAvg: loadAvg,
        osRelease: osRelease,
        kernelVersion: kernel,
        timestamp: DateTime.now(),
        networkDownloadSpeedKbps: rxKbps,
        networkUploadSpeedKbps: txKbps,
        cpuTemperatureCelsius: cpuTemp,
        disks: disksList,
        cpuModel: cpuModel,
      );
    } catch (e) {
      await disconnect();
      return SystemMetrics.empty();
    }
  }

  Future<List<ProcessInfo>> fetchRunningProcesses() async {
    if (!isConnected) return [];
    try {
      const script =
          'cores=\$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1); '
          'if [ -z "\$cores" ] || [ "\$cores" -le 0 ] 2>/dev/null; then cores=1; fi; '
          'ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 60 | awk -v c="\$cores" \'NR==1 {print \$0; next} { \$3 = sprintf("%.1f", \$3 / c); print \$0 }\'';
      final output = await executeCommand(script, timeout: const Duration(seconds: 10));
      if (output.isEmpty) return [];
      final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final processes = <ProcessInfo>[];
      for (int i = 1; i < lines.length; i++) {
        processes.add(ProcessInfo.fromPsLine(lines[i]));
      }
      return processes;
    } catch (e) {
      return [];
    }
  }

  Future<void> sendSignalToProcess(int pid, int signal, [String? sudoPassword]) async {
    if (!isConnected) throw Exception('SSH client not connected.');
    if (pid <= 0 || signal <= 0 || signal > 64) {
      throw ArgumentError('Security check: invalid PID ($pid) or signal ($signal).');
    }
    if (sudoPassword != null && sudoPassword.isNotEmpty) {
      await executeSudoCommand('kill -$signal $pid', sudoPassword);
    } else {
      await executeCommand('kill -$signal $pid');
    }
  }

  Future<List<DockerContainer>> fetchDockerContainers() async {
    if (!isConnected) return [];
    try {
      final output = await executeCommand("docker ps -a --format '{{json .}}'", timeout: const Duration(seconds: 10));
      if (output.isEmpty) return [];

      final lines = output.split('\n').where((l) => l.trim().isNotEmpty);
      final containers = <DockerContainer>[];

      for (final line in lines) {
        try {
          final map = jsonDecode(line) as Map<String, dynamic>;
          containers.add(DockerContainer.fromJson(map));
        } catch (e) {
          // Se una riga json è malformata, la saltiamo
        }
      }
      return containers;
    } catch (e) {
      return [];
    }
  }

  // [H3] Container ID validation with length limit
  void _validateContainerId(String id) {
    if (id.isEmpty || id.length > 128 || !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(id)) {
      throw ArgumentError('Security check: invalid container ID format.');
    }
  }

  // [H3] All Docker commands use shell-quoted container IDs
  Future<bool> startContainer(String id) async {
    _validateContainerId(id);
    await executeCommand('docker start "$id"');
    return true;
  }

  Future<bool> stopContainer(String id) async {
    _validateContainerId(id);
    await executeCommand('docker stop "$id"');
    return true;
  }

  Future<bool> restartContainer(String id) async {
    _validateContainerId(id);
    await executeCommand('docker restart "$id"');
    return true;
  }

  Future<String> fetchContainerLogs(String id, {int tail = 150}) async {
    _validateContainerId(id);
    if (tail <= 0 || tail > 10000) tail = 150;
    return await executeCommand('docker logs --tail $tail "$id" 2>&1');
  }

  // [C4] Validate command input at the sudo API boundary
  static void _validateCommandInput(String command) {
    if (command.length > 4096) {
      throw ArgumentError('Security check: command exceeds maximum allowed length (4096 chars).');
    }
    if (command.contains('\x00')) {
      throw ArgumentError('Security check: null bytes are forbidden in commands.');
    }
    // Newlines in the command itself are dangerous — the base64 encoding handles transport,
    // but the decoded command should not contain control characters that could escape the shell.
    if (command.contains('\r')) {
      throw ArgumentError('Security check: carriage returns are forbidden in commands.');
    }
  }

  Future<String> executeSudoCommand(String command, String sudoPassword, {Duration timeout = const Duration(seconds: 25)}) async {
    if (!isConnected) {
      throw Exception('SSH client not connected.');
    }
    _validateCommandInput(command);
    _isBusyWithCommand = true;
    try {
      final base64Cmd = base64Encode(utf8.encode(command));
      final session = await _client!.execute('sudo -S -p \'\' sh 2>&1').timeout(timeout);
      if (sudoPassword.isNotEmpty) {
        session.stdin.add(utf8.encode('$sudoPassword\n'));
      }
      session.stdin.add(utf8.encode('echo \'$base64Cmd\' | base64 -d | sh\nexit\n'));
      await session.stdin.close();

      final outputBytes = await session.stdout.fold<List<int>>(<int>[], (prev, element) => prev..addAll(element));
      final errorBytes = await session.stderr.fold<List<int>>(<int>[], (prev, element) => prev..addAll(element));
      await session.done;

      final stdoutStr = utf8.decode(outputBytes, allowMalformed: true).trim();
      final stderrStr = utf8.decode(errorBytes, allowMalformed: true).trim();

      if (session.exitCode != 0 && stderrStr.isNotEmpty && stdoutStr.isEmpty) {
        throw Exception(stderrStr);
      }
      return stdoutStr;
    } catch (e) {
      if (_client != null && (_client!.isClosed || e is SocketException || e.toString().contains('closed') || e.toString().contains('Broken pipe') || e.toString().contains('Connection reset'))) {
        await disconnect();
      }
      rethrow;
    } finally {
      _isBusyWithCommand = false;
    }
  }

  /// Executes a sudo command with real-time streaming of stdout/stderr via callbacks.
  /// Used for long-running commands (e.g. system updates) where the UI needs live output.
  Future<String> executeSudoCommandStreamed(
    String command,
    String sudoPassword, {
    Duration timeout = const Duration(minutes: 10),
    void Function(String chunk)? onStdout,
    void Function(String chunk)? onStderr,
  }) async {
    if (!isConnected) {
      throw Exception('SSH client not connected.');
    }
    _validateCommandInput(command);
    _isBusyWithCommand = true;
    try {
      final base64Cmd = base64Encode(utf8.encode(command));
      final session = await _client!.execute('sudo -S -p \'\' sh 2>&1').timeout(timeout);
      if (sudoPassword.isNotEmpty) {
        session.stdin.add(utf8.encode('$sudoPassword\n'));
      }
      session.stdin.add(utf8.encode('echo \'$base64Cmd\' | base64 -d | sh\nexit\n'));
      await session.stdin.close();

      final outputBuffer = StringBuffer();
      final completer = Completer<String>();

      // Listen to stdout chunks in real time
      session.stdout.listen(
        (data) {
          final chunk = utf8.decode(data, allowMalformed: true);
          outputBuffer.write(chunk);
          onStdout?.call(chunk);
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Listen to stderr chunks in real time
      session.stderr.listen(
        (data) {
          final chunk = utf8.decode(data, allowMalformed: true);
          onStderr?.call(chunk);
        },
      );

      // Wait for session to complete
      await session.done;

      final result = outputBuffer.toString().trim();
      if (!completer.isCompleted) {
        completer.complete(result);
      }

      return await completer.future.timeout(timeout);
    } catch (e) {
      if (_client != null && (_client!.isClosed || e is SocketException || e.toString().contains('closed') || e.toString().contains('Broken pipe') || e.toString().contains('Connection reset'))) {
        await disconnect();
      }
      rethrow;
    } finally {
      _isBusyWithCommand = false;
    }
  }

  Future<void> rebootServer([String? sudoPassword]) async {
    try {
      if (sudoPassword != null && sudoPassword.isNotEmpty) {
        await executeSudoCommand('reboot', sudoPassword, timeout: const Duration(seconds: 3));
      } else {
        await executeCommand('sudo reboot', timeout: const Duration(seconds: 3));
      }
    } catch (_) {
      // La disconnessione immediata causata dal reboot è attesa
    }
  }

  Future<void> shutdownServer([String? sudoPassword]) async {
    try {
      if (sudoPassword != null && sudoPassword.isNotEmpty) {
        await executeSudoCommand('poweroff', sudoPassword, timeout: const Duration(seconds: 3));
      } else {
        await executeCommand('sudo poweroff', timeout: const Duration(seconds: 3));
      }
    } catch (_) {
      // La disconnessione immediata causata da poweroff è attesa
    }
  }

  Future<SSHSession> startShellSession({int width = 80, int height = 24}) async {
    if (!isConnected) {
      throw Exception('SSH client not connected.');
    }
    return await _client!.shell(
      pty: SSHPtyConfig(
        width: width,
        height: height,
        type: 'xterm-256color',
      ),
    );
  }
}
