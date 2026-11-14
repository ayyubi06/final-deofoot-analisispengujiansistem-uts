import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/recurring_logic.dart';
import 'package:deofoot/report_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day labels use the Indonesian weekday names', () {
    expect(dayLabel(DateTime(2026, 11, 15)), 'Min');
    expect(dayLabel(DateTime(2026, 11, 16)), 'Sen');
    expect(dayLabel(DateTime(2026, 11, 17)), 'Sel');
    expect(dayLabel(DateTime(2026, 11, 18)), 'Rab');
    expect(dayLabel(DateTime(2026, 11, 19)), 'Kam');
    expect(dayLabel(DateTime(2026, 11, 20)), 'Jum');
    expect(dayLabel(DateTime(2026, 11, 21)), 'Sab');
  });

  test('custom report range defaults to today', () {
    final now = DateTime(2026, 11, 14, 12, 30);
    final (start, end) = rentangPreset(JenisRentang.pilihan, now);
    expect(start, DateTime(2026, 11, 14));
    expect(end, DateTime(2026, 11, 14));
  });

  test('unknown series status passes through unchanged', () {
    expect(labelStatusSeri('custom-status'), 'custom-status');
  });
}
