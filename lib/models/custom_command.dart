import 'dart:math';

class CustomCommand {
  final String id;
  final String title;
  final String command;
  final String iconName;

  CustomCommand({
    required this.id,
    required this.title,
    required this.command,
    required this.iconName,
  });

  static String generateId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(8, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  CustomCommand copyWith({
    String? id,
    String? title,
    String? command,
    String? iconName,
  }) {
    return CustomCommand(
      id: id ?? this.id,
      title: title ?? this.title,
      command: command ?? this.command,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'command': command,
      'iconName': iconName,
    };
  }

  factory CustomCommand.fromJson(Map<String, dynamic> json) {
    return CustomCommand(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unnamed',
      command: json['command']?.toString() ?? '',
      iconName: json['iconName']?.toString() ?? 'terminal',
    );
  }
}
