import 'package:flutter_test/flutter_test.dart';
import 'package:screenclean/shared/utils/formatters.dart';

void main() {
  test('formatDate uses unambiguous day-month short format', () {
    final formatted = formatDate(DateTime(2026, 2, 11));
    expect(formatted, '11 Feb');
  });
}
