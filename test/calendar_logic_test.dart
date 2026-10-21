import 'package:flutter_test/flutter_test.dart';

import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/calendar_logic.dart';
import 'package:deofoot/models.dart';

/// Test logika murni penanda kalender G8 (§3.3): titik volt bila
/// masih ada slot bebas, "Penuh" bila semua slot terisi/pending
/// atau sudah lewat. Semantik slot sama seperti grid (slotStatuses).
void main() {
  Booking bk(String date, String start, String end, String status) {
    return Booking(
      id: 'b-$date-$start-$status',
      userId: 'u1',
      userEmail: 'u@test.id',
      fieldId: 'f1',
      fieldName: 'Lapangan 1',
      date: date,
      startTime: start,
      endTime: end,
      status: status,
      totalPrice: 120000,
      pricePerHour: 120000,
      whatsapp: '081234567890',
      createdAt: DateTime(2026, 10, 1),
    );
  }

  // "Sekarang" tetap: Rabu 21 Okt 2026 pukul 09.30.
  final now = DateTime(2026, 10, 21, 9, 30);
  final tomorrow = DateTime(2026, 10, 22);
  final tomorrowStr = fmtDate(tomorrow);

  test('tanggal kosong tanpa booking -> hasFree', () {
    expect(dayMark([], 'f1', tomorrow, now), DayMark.hasFree);
  });

  test('semua slot confirmed -> full', () {
    final all = [
      bk(tomorrowStr, '08:00', '22:00', 'confirmed'),
    ];
    expect(dayMark(all, 'f1', tomorrow, now), DayMark.full);
  });

  test('semua slot pending -> full (pending bukan bebas)', () {
    final all = [bk(tomorrowStr, '08:00', '22:00', 'pending')];
    expect(dayMark(all, 'f1', tomorrow, now), DayMark.full);
  });

  test('sebagian terisi, sisa bebas -> hasFree', () {
    final some = [bk(tomorrowStr, '08:00', '12:00', 'confirmed')];
    expect(dayMark(some, 'f1', tomorrow, now), DayMark.hasFree);
  });

  test('booking cancelled tidak menutup slot -> hasFree', () {
    final cancelled = [bk(tomorrowStr, '08:00', '22:00', 'cancelled')];
    expect(dayMark(cancelled, 'f1', tomorrow, now), DayMark.hasFree);
  });

  test('booking lapangan lain tidak dihitung -> hasFree', () {
    final other = [
      Booking(
        id: 'bx',
        userId: 'u1',
        userEmail: 'u@test.id',
        fieldId: 'f2',
        fieldName: 'Lapangan 2',
        date: tomorrowStr,
        startTime: '08:00',
        endTime: '22:00',
        status: 'confirmed',
        totalPrice: 1,
        pricePerHour: 1,
        whatsapp: '081234567890',
        createdAt: DateTime(2026, 10, 1),
      ),
    ];
    expect(dayMark(other, 'f1', tomorrow, now), DayMark.hasFree);
  });

  test('hari ini: slot bebas yang sudah lewat tidak dihitung', () {
    // Pukul 09.30 -> slot 08 & 09 sudah lewat. Sisa hari ini
    // (10..21) dibooking semua -> full walau 08-09 "bebas".
    final todayStr = fmtDate(now);
    final rest = [bk(todayStr, '10:00', '22:00', 'confirmed')];
    expect(dayMark(rest, 'f1', DateTime(2026, 10, 21), now), DayMark.full);
  });

  test('hari ini: satu slot depan masih bebas -> hasFree', () {
    final todayStr = fmtDate(now);
    final rest = [bk(todayStr, '10:00', '21:00', 'confirmed')];
    expect(dayMark(rest, 'f1', DateTime(2026, 10, 21), now), DayMark.hasFree);
  });

  test('format tanggal Indonesia lengkap', () {
    expect(indoFullDate(DateTime(2026, 10, 21)), 'Rabu, 21 Oktober 2026');
    expect(indoMonthYear(DateTime(2026, 12, 1)), 'Desember 2026');
  });
}
