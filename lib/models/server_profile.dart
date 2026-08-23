import 'dart:math';
import '../utils/command_validator.dart';
import 'custom_command.dart';

class ServerProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String privateKey;
  final bool useAuthKey;
  final String customUpdateCommand;
  final bool useCloudflareTunnel;
  final String cloudflareClientId;
  final String cloudflareClientSecret;
  final List<CustomCommand> customCommands;

  ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password = '',
    this.privateKey = '',
    this.useAuthKey = false,
    this.customUpdateCommand = 'sudo apt update && sudo apt upgrade -y',
    this.useCloudflareTunnel = false,
    this.cloudflareClientId = '',
    this.cloudflareClientSecret = '',
    this.customCommands = const [],
  });

  /// [M1] Generate a cryptographically secure random ID (32 hex chars)
  static String generateSecureId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// [H2] Returns a copy of this profile with all secrets cleared.
  /// Use this for public-facing getters to avoid credential exposure.
  ServerProfile sanitized() {
    return copyWith(
      password: '',
      privateKey: '',
      cloudflareClientId: '',
      cloudflareClientSecret: '',
    );
  }

  /// Validates if a given host is a valid IP address or FQDN
  static bool isValidHost(String host) {
    if (host.isEmpty) return false;
    // Basic IP validation
    final ipRegExp = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    // IPv6 validation
    final ipv6RegExp = RegExp(r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$');
    // Basic FQDN/Hostname validation
    final fqdnRegExp = RegExp(r'^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]))*$');
    
    return ipRegExp.hasMatch(host) || fqdnRegExp.hasMatch(host) || ipv6RegExp.hasMatch(host) || host == 'localhost';
  }

  ServerProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    bool? useAuthKey,
    String? customUpdateCommand,
    bool? useCloudflareTunnel,
    String? cloudflareClientId,
    String? cloudflareClientSecret,
    List<CustomCommand>? customCommands,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      useAuthKey: useAuthKey ?? this.useAuthKey,
      customUpdateCommand: customUpdateCommand ?? this.customUpdateCommand,
      useCloudflareTunnel: useCloudflareTunnel ?? this.useCloudflareTunnel,
      cloudflareClientId: cloudflareClientId ?? this.cloudflareClientId,
      cloudflareClientSecret: cloudflareClientSecret ?? this.cloudflareClientSecret,
      customCommands: customCommands ?? this.customCommands,
    );
  }

  Map<String, dynamic> toJson({bool includeSecrets = false}) {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': includeSecrets ? password : '',
      'privateKey': includeSecrets ? privateKey : '',
      'useAuthKey': useAuthKey,
      'customUpdateCommand': includeSecrets ? customUpdateCommand : '',
      'useCloudflareTunnel': useCloudflareTunnel,
      // [M4] cloudflareClientId is now treated as sensitive — stripped unless includeSecrets
      'cloudflareClientId': includeSecrets ? cloudflareClientId : '',
      'cloudflareClientSecret': includeSecrets ? cloudflareClientSecret : '',
      'customCommands': customCommands.map((c) => c.toJson()).toList(),
    };
  }

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    String parsedHost = json['host']?.toString() ?? '';
    if (!isValidHost(parsedHost)) {
      parsedHost = ''; // Reset invalid host to prevent SSRF
    }

    String parsedCommand = json['customUpdateCommand']?.toString() ?? 'sudo apt update && sudo apt upgrade -y';
    if (parsedCommand.isNotEmpty && parsedCommand != 'sudo apt update && sudo apt upgrade -y') {
      final validation = CommandValidator.validateUpdateCommand(parsedCommand);
      if (validation.isBlocked) {
        parsedCommand = 'sudo apt update && sudo apt upgrade -y'; // Fallback to safe default
      }
    }

    List<CustomCommand> parsedCustomCommands = [];
    if (json['customCommands'] != null && json['customCommands'] is List) {
      parsedCustomCommands = (json['customCommands'] as List)
          .map((item) => CustomCommand.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return ServerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Server',
      host: parsedHost,
      port: (json['port'] is int) ? json['port'] : int.tryParse(json['port']?.toString() ?? '22') ?? 22,
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      privateKey: json['privateKey']?.toString() ?? '',
      useAuthKey: json['useAuthKey'] == true,
      customUpdateCommand: parsedCommand,
      useCloudflareTunnel: json['useCloudflareTunnel'] == true,
      cloudflareClientId: json['cloudflareClientId']?.toString() ?? '',
      cloudflareClientSecret: json['cloudflareClientSecret']?.toString() ?? '',
      customCommands: parsedCustomCommands,
    );
  }
}
