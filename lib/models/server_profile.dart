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
  });

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
      'customUpdateCommand': customUpdateCommand,
      'useCloudflareTunnel': useCloudflareTunnel,
      'cloudflareClientId': cloudflareClientId,
      'cloudflareClientSecret': includeSecrets ? cloudflareClientSecret : '',
    };
  }

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Server',
      host: json['host']?.toString() ?? '',
      port: (json['port'] is int) ? json['port'] : int.tryParse(json['port']?.toString() ?? '22') ?? 22,
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      privateKey: json['privateKey']?.toString() ?? '',
      useAuthKey: json['useAuthKey'] == true,
      customUpdateCommand: json['customUpdateCommand']?.toString() ?? 'sudo apt update && sudo apt upgrade -y',
      useCloudflareTunnel: json['useCloudflareTunnel'] == true,
      cloudflareClientId: json['cloudflareClientId']?.toString() ?? '',
      cloudflareClientSecret: json['cloudflareClientSecret']?.toString() ?? '',
    );
  }
}
