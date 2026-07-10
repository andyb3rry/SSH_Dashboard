class DockerContainer {
  final String id;
  final String name;
  final String image;
  final String state;
  final String status;
  final String ports;

  DockerContainer({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    required this.ports,
  });

  bool get isRunning => state.toLowerCase() == 'running';
  bool get isPaused => state.toLowerCase() == 'paused';
  bool get isExited => state.toLowerCase() == 'exited' || state.toLowerCase() == 'dead';

  factory DockerContainer.fromJson(Map<String, dynamic> json) {
    // Gestione di formati con chiavi maiuscole dal format docker {{json .}} o minuscole
    String rawNames = (json['Names'] ?? json['names'] ?? 'Unknown').toString();
    // A volte Docker names contengono più nomi o prefissi con slash
    if (rawNames.startsWith('/')) {
      rawNames = rawNames.substring(1);
    }

    return DockerContainer(
      id: (json['ID'] ?? json['Id'] ?? json['id'] ?? '').toString(),
      name: rawNames,
      image: (json['Image'] ?? json['image'] ?? '').toString(),
      state: (json['State'] ?? json['state'] ?? 'unknown').toString(),
      status: (json['Status'] ?? json['status'] ?? '').toString(),
      ports: (json['Ports'] ?? json['ports'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'Names': name,
      'Image': image,
      'State': state,
      'Status': status,
      'Ports': ports,
    };
  }
}
