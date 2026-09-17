class AppDateFormatter {
  static const List<String> _dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _shortMonthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Format: "15 September 2026"
  static String formatDate(DateTime dt) {
    final monthName = _monthNames[(dt.month - 1).clamp(0, 11)];
    return '${dt.day} $monthName ${dt.year}';
  }

  /// Format: "Senin, 15 September 2026"
  static String formatFullDate(DateTime dt) {
    final dayName = _dayNames[(dt.weekday - 1).clamp(0, 6)];
    final monthName = _monthNames[(dt.month - 1).clamp(0, 11)];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  /// Format: "15 Sep 08:00"
  static String formatShortDateTime(DateTime dt) {
    final month = _shortMonthNames[(dt.month - 1).clamp(0, 11)];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month $hour:$minute';
  }

  /// Format: "15 September 2026, 08:00"
  static String formatFullDateTime(DateTime dt) {
    final month = _monthNames[(dt.month - 1).clamp(0, 11)];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month ${dt.year}, $hour:$minute';
  }
}
