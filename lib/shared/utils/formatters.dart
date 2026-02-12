String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }

  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  var suffixIndex = 0;

  while (value >= 1024 && suffixIndex < suffixes.length - 1) {
    value /= 1024;
    suffixIndex++;
  }

  final precision = value >= 100 || suffixIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${suffixes[suffixIndex]}';
}

String formatDate(DateTime dateTime) {
  const monthShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = monthShort[dateTime.month - 1];
  final now = DateTime.now();
  if (dateTime.year != now.year) {
    final year = dateTime.year.toString().substring(2);
    return '$day $month \'$year';
  }
  return '$day $month';
}
