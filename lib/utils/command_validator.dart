enum ValidationSeverity { safe, warning, blocked }

class ValidationResult {
  final bool isSafe;
  final ValidationSeverity severity;
  final String? message;

  const ValidationResult({
    required this.isSafe,
    required this.severity,
    this.message,
  });

  bool get isBlocked => severity == ValidationSeverity.blocked;
  bool get isWarning => severity == ValidationSeverity.warning;
}

class CommandValidator {
  /// Whitelist of exact pre-approved system update commands (normalized whitespace).
  static const List<String> _whitelistedUpdateCommands = [
    // Debian / Ubuntu (apt / apt-get)
    'sudo apt update && sudo apt upgrade -y',
    'sudo apt update && sudo apt -y upgrade',
    'sudo apt update && sudo apt upgrade',
    'sudo apt update && sudo apt full-upgrade -y',
    'sudo apt update && sudo apt -y full-upgrade',
    'sudo apt update && sudo apt full-upgrade',
    'sudo apt update && sudo apt dist-upgrade -y',
    'sudo apt update && sudo apt -y dist-upgrade',
    'sudo apt update && sudo apt dist-upgrade',
    'sudo apt-get update && sudo apt-get upgrade -y',
    'sudo apt-get update && sudo apt-get -y upgrade',
    'sudo apt-get update && sudo apt-get upgrade',
    'sudo apt-get update && sudo apt-get dist-upgrade -y',
    'sudo apt-get update && sudo apt-get -y dist-upgrade',
    'sudo apt-get update && sudo apt-get dist-upgrade',
    'sudo apt update && sudo do-release-upgrade',
    'sudo apt update',
    'sudo apt upgrade -y',
    'sudo apt -y upgrade',
    'sudo apt upgrade',
    'sudo apt-get update',
    'sudo apt-get upgrade -y',
    'sudo apt-get -y upgrade',
    'sudo apt-get upgrade',
    'sudo apt update && apt upgrade -y',
    'sudo apt update && apt -y upgrade',
    'sudo apt update && apt upgrade',
    'sudo apt-get update && apt-get upgrade -y',
    'sudo apt-get update && apt-get -y upgrade',
    'sudo apt-get update && apt-get upgrade',
    // Debian / Ubuntu (non-sudo root variants)
    'apt update && apt upgrade -y',
    'apt update && apt -y upgrade',
    'apt update && apt upgrade',
    'apt update && apt full-upgrade -y',
    'apt update && apt -y full-upgrade',
    'apt update && apt full-upgrade',
    'apt update && apt dist-upgrade -y',
    'apt update && apt -y dist-upgrade',
    'apt update && apt dist-upgrade',
    'apt-get update && apt-get upgrade -y',
    'apt-get update && apt-get -y upgrade',
    'apt-get update && apt-get upgrade',
    'apt-get update && apt-get dist-upgrade -y',
    'apt-get update && apt-get -y dist-upgrade',
    'apt-get update && apt-get dist-upgrade',
    'apt update && do-release-upgrade',
    'apt update',
    'apt upgrade -y',
    'apt -y upgrade',
    'apt upgrade',
    'apt-get update',
    'apt-get upgrade -y',
    'apt-get -y upgrade',
    'apt-get upgrade',
    // Fedora / RHEL / CentOS / Rocky / AlmaLinux (dnf / yum)
    'sudo dnf update -y',
    'sudo dnf update',
    'sudo dnf upgrade -y',
    'sudo dnf upgrade',
    'sudo dnf check-update && sudo dnf upgrade -y',
    'dnf update -y',
    'dnf update',
    'dnf upgrade -y',
    'dnf upgrade',
    'sudo yum update -y',
    'sudo yum update',
    'yum update -y',
    'yum update',
    // Arch Linux / EndeavourOS / Manjaro (pacman)
    'sudo pacman -Syu --noconfirm',
    'sudo pacman -Syu',
    'pacman -Syu --noconfirm',
    'pacman -Syu',
    // Alpine Linux (apk)
    'sudo apk update && sudo apk upgrade',
    'apk update && apk upgrade',
    // openSUSE / SUSE Linux (zypper)
    'sudo zypper update -y',
    'sudo zypper update',
    'sudo zypper dup -y',
    'sudo zypper dup',
    'zypper update -y',
    'zypper update',
    'zypper dup -y',
    'zypper dup',
    // Snap / Flatpak packages
    'sudo snap refresh',
    'snap refresh',
    'flatpak update -y',
    'flatpak update',
    'sudo flatpak update -y',
    'sudo flatpak update',
  ];

  /// Whitelist of safe, standard system binaries/utilities allowed as commands in crontab.
  static const List<String> _whitelistedCronBinaries = [
    'rsync', 'tar', 'gzip', 'gunzip', 'bzip2', 'xz', 'zip', 'unzip',
    'borg', 'restic', 'rclone', 'pg_dump', 'pg_dumpall', 'mysqldump', 'sqlite3',
    'mysql', 'psql', 'mongodump', 'redis-cli',
    'apt', 'apt-get', 'dpkg', 'dnf', 'yum', 'pacman', 'zypper', 'apk', 'snap', 'flatpak',
    'systemctl', 'service', 'journalctl', 'logrotate', 'find', 'fstrim', 'updatedb', 'ldconfig',
    'certbot', 'docker', 'podman', 'zpool', 'zfs', 'btrfs', 'mdadm', 'smartctl',
    'php', 'python', 'python3', 'node', 'npm', 'pm2', 'java', 'ruby',
    'curl', 'wget', 'git',
    'echo', 'true', 'date',
  ];

  /// Whitelist of directory prefixes allowed for executing scripts or binaries in crontab.
  static const List<String> _whitelistedScriptDirectories = [
    '/home/',
    '/root/',
    '/opt/',
    '/usr/local/bin/',
    '/usr/local/sbin/',
    '/usr/bin/',
    '/usr/sbin/',
    '/bin/',
    '/sbin/',
    '/srv/',
    '/var/www/',
    '/var/backups/',
  ];

  /// Forbidden patterns that must never be executed regardless of context.
  static const List<String> _forbiddenPatterns = [
    'rm -rf',
    'rm -r ',
    'rm -f /',
    'mkfifo',
    '/dev/tcp/',
    '/dev/udp/',
    'nc -e',
    'nc -c',
    'ncat -e',
    'netcat -e',
    'python -c',
    'python3 -c',
    'python -i',
    'python3 -i',
    'perl -e',
    'ruby -e',
    'ruby -i',
    'php -r',
    'php -a',
    'node -e',
    'node --eval',
    'node -i',
    'node --interactive',
    'bash -i',
    'sh -i',
    'eval ',
    'chmod 777',
    'chown -R',
    'dd if=',
    '> /etc/',
    '>> /etc/',
    '> /boot/',
    '>> /boot/',
    '> /bin/',
    '>> /bin/',
    '> /sbin/',
    '>> /sbin/',
    '> /usr/',
    '>> /usr/',
    '> /lib/',
    '>> /lib/',
    '> /proc/',
    '>> /proc/',
    '> /sys/',
    '>> /sys/',
  ];

  /// Validates a custom system update command before saving or executing.
  /// Strictly whitelisted: blocks everything by default unless explicitly pre-approved.
  static ValidationResult validateUpdateCommand(String command) {
    final cleanCmd = command.trim();
    if (cleanCmd.isEmpty) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Update command cannot be empty.',
      );
    }

    // Normalize multiple spaces to single space
    final normalizedCmd = cleanCmd.replaceAll(RegExp(r'\s+'), ' ');
    final normalizedLower = normalizedCmd.toLowerCase();

    for (final whitelisted in _whitelistedUpdateCommands) {
      if (whitelisted.toLowerCase() == normalizedLower) {
        return const ValidationResult(
          isSafe: true,
          severity: ValidationSeverity.safe,
        );
      }
    }

    // Default block for any command not exactly matching the whitelist
    return const ValidationResult(
      isSafe: false,
      severity: ValidationSeverity.blocked,
      message: 'Not an update command - see whitelist (e.g. sudo apt update && sudo apt upgrade -y)',
    );
  }

  /// Validates a crontab schedule and command before saving or executing.
  /// Blocks by default (`default block`) and authorizes only commands that run whitelisted binaries or scripts from whitelisted paths.
  static ValidationResult validateCronJob(String schedule, String command, {required bool isRoot}) {
    final cleanCmd = command.trim();
    final cleanSchedule = schedule.trim();

    if (cleanCmd.isEmpty || cleanSchedule.isEmpty) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Schedule and command must not be empty.',
      );
    }

    // [H5] Block newlines, carriage returns, and null bytes — prevents multi-line injection
    if (cleanCmd.contains('\n') || cleanCmd.contains('\r') || cleanCmd.contains('\x00')) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: newlines, carriage returns, and null bytes are forbidden in crontab commands.',
      );
    }

    // [H5] Block heredocs and process substitution operators
    if (cleanCmd.contains('<<') || cleanCmd.contains('<(') || cleanCmd.contains('>(')) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: heredoc (<<) and process substitution (<( / >() operators are forbidden in crontab.',
      );
    }

    // Check for subshells `...` or $(...) including nested
    if (cleanCmd.contains('`') || RegExp(r'\$\(').hasMatch(cleanCmd)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: command substitution / subshells (` or \$()) are forbidden in crontab.',
      );
    }

    // [H4] Check for dangerous or forbidden substrings — CASE-INSENSITIVE
    final cleanCmdLower = cleanCmd.toLowerCase();
    for (final pattern in _forbiddenPatterns) {
      if (cleanCmdLower.contains(pattern.toLowerCase())) {
        return ValidationResult(
          isSafe: false,
          severity: ValidationSeverity.blocked,
          message: 'Blocked: dangerous command pattern detected ($pattern).',
        );
      }
    }

    // Check for pipe from curl/wget to shell or interpreters
    if (RegExp(r'(curl|wget)\s+[^|]+\|\s*(sudo\s+|env\s+)?(bash|sh|zsh|python|python3|node|perl|ruby|php)').hasMatch(cleanCmd)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: downloading and piping directly to shell or interpreters is forbidden in crontab.',
      );
    }

    // Check for world-writable execution paths (/tmp, /var/tmp, /dev/shm) or non-whitelisted paths
    if (RegExp(r'(^|\s|\||&&|;)(sudo\s+)?(bash|sh|python|python3|perl|ruby|php|node|/bin/sh|/bin/bash)?\s*[\042\047]?/(var/)?tmp/').hasMatch(cleanCmd) ||
        RegExp(r'(^|\s|\||&&|;)(sudo\s+)?(bash|sh|python|python3|perl|ruby|php|node|/bin/sh|/bin/bash)?\s*[\042\047]?/dev/shm/').hasMatch(cleanCmd)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: root/user cron jobs must not execute scripts from world-writable directories (/tmp, /var/tmp, /dev/shm).',
      );
    }

    // [H5] Strict Whitelist check on all command segments (split by &&, ||, ;, and | pipes)
    final segments = cleanCmd.split(RegExp(r'(\s*&&\s*|\s*\|\|\s*|\s*;\s*|\s*\|\s*)'));
    for (var segment in segments) {
      final s = segment.trim();
      if (s.isEmpty) continue;
      
      // Strip leading env/sudo modifiers if any
      final cleanSegment = s.replaceAll(RegExp(r'^(sudo|env)\s+'), '').trim();
      if (cleanSegment.isEmpty) continue;

      final words = cleanSegment.split(RegExp(r'\s+'));
      final firstWord = words.first;
      final mainCmdLower = firstWord.toLowerCase();

      // Check if firstWord matches whitelisted cron binaries
      final isWhitelistedBinary = _whitelistedCronBinaries.contains(mainCmdLower);

      // Check if firstWord is an absolute path starting with a whitelisted directory
      bool isWhitelistedPath = false;
      if (firstWord.startsWith('/')) {
        for (final dir in _whitelistedScriptDirectories) {
          if (firstWord.startsWith(dir)) {
            isWhitelistedPath = true;
            break;
          }
        }
      }

      if (!isWhitelistedBinary && !isWhitelistedPath) {
        return ValidationResult(
          isSafe: false,
          severity: ValidationSeverity.blocked,
          message: 'Blocked by strict whitelist: `$firstWord` is neither an authorized utility nor inside a whitelisted script directory (`/home/`, `/root/`, `/opt/`, `/usr/local/bin/`, etc.).',
        );
      }
    }

    if (isRoot && cleanSchedule.startsWith('@reboot')) {
      if (cleanCmd.contains('curl ') || cleanCmd.contains('wget ') || cleanCmd.contains('|')) {
        return const ValidationResult(
          isSafe: false,
          severity: ValidationSeverity.blocked,
          message: 'Blocked: root @reboot jobs with network requests or pipes pose severe persistence risks.',
        );
      }
      return const ValidationResult(
        isSafe: true,
        severity: ValidationSeverity.warning,
        message: '⚠️ Root Boot Persistence: This whitelisted job will run automatically with root privileges every time the server boots.',
      );
    }

    return const ValidationResult(
      isSafe: true,
      severity: ValidationSeverity.safe,
    );
  }

  /// Validates custom commands to block any root privilege escalation or system-wide changes.
  /// Uses a defense-in-depth approach: control chars → shell operators → encoding tricks → blacklist → system paths.
  static ValidationResult validateCustomCommand(String command) {
    final cleanCmd = command.trim();
    if (cleanCmd.isEmpty) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Command cannot be empty.',
      );
    }

    // --- [S1] Length limit ---
    if (cleanCmd.length > 512) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Command exceeds maximum allowed length (512 characters).',
      );
    }

    // --- [S2] Block control characters: newlines, carriage returns, null bytes ---
    if (cleanCmd.contains('\n') || cleanCmd.contains('\r') || cleanCmd.contains('\x00')) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Newlines, carriage returns, and null bytes are forbidden.',
      );
    }

    // --- [S3] Block shell operators: command substitution, heredoc, process substitution ---
    if (cleanCmd.contains('`') || RegExp(r'\$\(').hasMatch(cleanCmd)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Command substitution (backtick or \$()) is forbidden in custom commands.',
      );
    }
    if (cleanCmd.contains('<<') || cleanCmd.contains('<(') || cleanCmd.contains('>(')) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Heredoc (<<) and process substitution (<( / >() are forbidden.',
      );
    }

    // --- [S4] Block encoding/escaping bypass tricks ---
    // Backslash inside command words (e.g. s\udo → sudo in bash)
    if (RegExp(r'[a-zA-Z]\\[a-zA-Z]').hasMatch(cleanCmd)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Backslash escaping within command words is forbidden.',
      );
    }
    // Empty-quote concatenation (e.g. su""do, su''do)
    if (RegExp(r'[a-zA-Z]("")|[a-zA-Z](' "''" r')[a-zA-Z]').hasMatch(cleanCmd)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Empty-quote concatenation within command words is forbidden.',
      );
    }
    // $IFS or ${IFS} used as space substitute
    if (RegExp(r'\$IFS|\$\{IFS\}', caseSensitive: false).hasMatch(cleanCmd)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: r'Blocked: $IFS variable substitution is forbidden.',
      );
    }

    final cleanCmdLower = cleanCmd.toLowerCase();

    // --- [S5] Block bash builtins used as bypass wrappers ---
    final bypassPrefixes = [
      'command ', 'builtin ',
      'bash -c', 'bash -i', 'sh -c', 'sh -i', 'zsh -c',
      '/bin/bash -c', '/bin/sh -c', '/usr/bin/bash -c', '/usr/bin/sh -c',
      'env ', 'nohup ',
    ];
    for (final prefix in bypassPrefixes) {
      if (cleanCmdLower.startsWith(prefix) || cleanCmdLower.contains(' $prefix') || cleanCmdLower.contains(';$prefix') || cleanCmdLower.contains('|$prefix')) {
        return ValidationResult(
          isSafe: false,
          severity: ValidationSeverity.blocked,
          message: 'Blocked: Shell wrapper "$prefix" is forbidden in custom commands.',
        );
      }
    }

    // --- [S6] Blacklist of root tools, package managers, and destructive operations ---
    // Matches both "sudo ..." and standalone "sudo" at end of string
    final List<String> blacklist = [
      'sudo', 'su', 'doas', 'pkexec',
      'apt', 'apt-get', 'dpkg', 'snap', 'flatpak',
      'yum', 'dnf', 'rpm', 'pacman', 'zypper', 'apk',
      'chmod', 'chown', 'chgrp',
      'passwd', 'useradd', 'userdel', 'usermod', 'groupadd',
      'mount', 'umount', 'mkfs', 'fdisk', 'parted',
      'iptables', 'nft', 'firewall-cmd', 'ufw',
      'insmod', 'rmmod', 'modprobe',
      'dd',
    ];

    // Split on shell separators to check each segment's leading command
    final segments = cleanCmdLower.split(RegExp(r'(\s*&&\s*|\s*\|\|\s*|\s*;\s*|\s*\|\s*)'));
    for (var segment in segments) {
      final s = segment.trim();
      if (s.isEmpty) continue;

      final words = s.split(RegExp(r'\s+'));
      var firstWord = words.first;

      // Strip absolute path to get basename (blocks /usr/bin/sudo etc.)
      if (firstWord.contains('/')) {
        firstWord = firstWord.split('/').last;
      }

      if (blacklist.contains(firstWord)) {
        return ValidationResult(
          isSafe: false,
          severity: ValidationSeverity.blocked,
          message: 'Blocked: "$firstWord" is a privileged/destructive command and cannot be used in custom commands.',
        );
      }
    }

    // --- [S7] Block dangerous substrings from _forbiddenPatterns (shared with cron) ---
    for (final pattern in _forbiddenPatterns) {
      if (cleanCmdLower.contains(pattern.toLowerCase())) {
        return ValidationResult(
          isSafe: false,
          severity: ValidationSeverity.blocked,
          message: 'Blocked: Dangerous command pattern detected ($pattern).',
        );
      }
    }

    // --- [S8] Block curl/wget piping to shell interpreters ---
    if (RegExp(r'(curl|wget)\s+[^|]+\|\s*(sudo\s+|env\s+)?(bash|sh|zsh|python|python3|node|perl|ruby|php)').hasMatch(cleanCmdLower)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Downloading and piping to a shell interpreter is forbidden.',
      );
    }

    // --- [S9] Block execution from world-writable directories ---
    if (RegExp(r'(^|\s|;|&&|\|)[\042\047]?/(var/)?tmp/').hasMatch(cleanCmdLower) ||
        RegExp(r'(^|\s|;|&&|\|)[\042\047]?/dev/shm/').hasMatch(cleanCmdLower)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Executing from world-writable directories (/tmp, /var/tmp, /dev/shm) is forbidden.',
      );
    }

    // --- [S10] Block modifications to sensitive system directories ---
    if (RegExp(r'(^|\s|\||&&|;)(>|>>)\s*/(etc|bin|sbin|usr|lib|boot|dev|sys|proc)/').hasMatch(cleanCmdLower)) {
      return const ValidationResult(
        isSafe: false,
        severity: ValidationSeverity.blocked,
        message: 'Blocked: Redirecting output to sensitive system directories is forbidden.',
      );
    }

    return const ValidationResult(
      isSafe: true,
      severity: ValidationSeverity.safe,
    );
  }
}
