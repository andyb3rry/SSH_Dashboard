class CronJob {
  final String rawLine;
  final String schedule;
  final String command;
  final String? lastExecutionLog;
  final bool isRoot;

  CronJob({
    required this.rawLine,
    required this.schedule,
    required this.command,
    this.lastExecutionLog,
    this.isRoot = false,
  });

  static const Map<String, String> _daysOfWeek = {
    '0': 'Sunday',
    '7': 'Sunday',
    '1': 'Monday',
    '2': 'Tuesday',
    '3': 'Wednesday',
    '4': 'Thursday',
    '5': 'Friday',
    '6': 'Saturday',
    'sun': 'Sunday',
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
    'sat': 'Saturday',
  };

  String get humanReadableSchedule {
    if (schedule == '@reboot') return 'At every system boot (@reboot)';
    if (schedule == '@daily' || schedule == '@midnight' || schedule == '0 0 * * *') return 'Every day at midnight (00:00)';
    if (schedule == '@hourly' || schedule == '0 * * * *') return 'Every hour at minute :00';
    if (schedule == '@weekly' || schedule == '0 0 * * 0') return 'Every week (Sunday at 00:00)';
    if (schedule == '@monthly' || schedule == '0 0 1 * *') return 'Every month (1st day at 00:00)';
    if (schedule == '@yearly' || schedule == '@annually' || schedule == '0 0 1 1 *') return 'Every year (Jan 1st at 00:00)';

    final parts = schedule.split(RegExp(r'\s+'));
    if (parts.length == 5) {
      final minPart = parts[0];
      final hrPart = parts[1];
      final dayPart = parts[2];
      final monthPart = parts[3];
      final dowPart = parts[4];

      // "*/X * * * *" -> Every X minutes
      if (minPart.startsWith('*/') && hrPart == '*' && dayPart == '*' && monthPart == '*' && dowPart == '*') {
        final minutes = minPart.replaceAll('*/', '');
        return minutes == '1' ? 'Every minute' : 'Every $minutes minutes';
      }

      // "0 */Y * * *" -> Every Y hours
      if (int.tryParse(minPart) != null && hrPart.startsWith('*/') && dayPart == '*' && monthPart == '*' && dowPart == '*') {
        final hours = hrPart.replaceAll('*/', '');
        return hours == '1' ? 'Every hour' : 'Every $hours hours';
      }

      // "X * * * *" -> Every hour at minute :XX
      if (int.tryParse(minPart) != null && hrPart == '*' && dayPart == '*' && monthPart == '*' && dowPart == '*') {
        final minStr = minPart.padLeft(2, '0');
        return 'Every hour at minute :$minStr';
      }

      // Exact time: "M H ..." where both M and H are numbers
      if (int.tryParse(minPart) != null && int.tryParse(hrPart) != null) {
        final minStr = minPart.padLeft(2, '0');
        final hrStr = hrPart.padLeft(2, '0');
        final timeStr = '$hrStr:$minStr';

        // Every day at HH:MM ("30 1 * * *")
        if (dayPart == '*' && monthPart == '*' && dowPart == '*') {
          return 'Every day at $timeStr';
        }

        // Every DayOfWeek at HH:MM ("30 1 * * 1" -> Every Monday at 01:30)
        final dowKey = dowPart.toLowerCase();
        if (dayPart == '*' && monthPart == '*' && _daysOfWeek.containsKey(dowKey)) {
          return 'Every ${_daysOfWeek[dowKey]} at $timeStr';
        }

        // Every month on day D at HH:MM ("0 4 15 * *")
        if (dayPart != '*' && int.tryParse(dayPart) != null && monthPart == '*' && dowPart == '*') {
          return 'Every month on day $dayPart at $timeStr';
        }

        // Every year on month M day D at HH:MM ("0 4 1 12 *")
        if (dayPart != '*' && int.tryParse(dayPart) != null && monthPart != '*' && int.tryParse(monthPart) != null && dowPart == '*') {
          return 'Every year on month $monthPart, day $dayPart at $timeStr';
        }
      }
    }

    return schedule;
  }
}
