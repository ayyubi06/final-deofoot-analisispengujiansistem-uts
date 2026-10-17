import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot_mvp/booking_logic.dart';
import 'package:deofoot_mvp/models.dart';

Booking _b({
  String fieldId = 'L1',
  String date = '2026-10-20',
  String start = '10:00',
  String end = '11:00',
  String status = 'confirmed',
}) =>
    Booking(
      id: 'x',
      userId: 'u',
      userEmail: 'u@x.id',
      fieldId: fieldId,
      fieldName: fieldId,
      date: date,
      startTime: start,
      endTime: end,
      status: status,
      totalPrice: 120000,
      createdAt: DateTime.now(),
    );

void main() {
  group('isOverlapping', () {
    test('overlap sebagian -> true', () {
      expect(isOverlapping(600, 660, 630, 690), true);
    });
    test('sama persis -> true', () {
      expect(isOverlapping(600, 660, 600, 660), true);
    });
    test('tepi bersentuhan (end==start) -> BUKAN konflik', () {
      expect(isOverlapping(600, 660, 660, 720), false);
      expect(isOverlapping(660, 720, 600, 660), false);
    });
    test('terpisah jauh -> false', () {
      expect(isOverlapping(480, 540, 600, 660), false);
    });
  });

  group('hasConflict (port cek_bentrok)', () {
    test('slot sama, booking confirmed -> konflik', () {
      expect(hasConflict([_b()], 'L1', '2026-10-20', 600, 660), true);
    });
    test('slot sama tapi status cancelled -> bebas', () {
      expect(
          hasConflict(
              [_b(status: 'cancelled')], 'L1', '2026-10-20', 600, 660),
          false);
    });
    test('slot sama tapi status rejected -> bebas', () {
      expect(
          hasConflict(
              [_b(status: 'rejected')], 'L1', '2026-10-20', 600, 660),
          false);
    });
    test('status pending -> dihitung terisi', () {
      expect(
          hasConflict(
              [_b(status: 'pending')], 'L1', '2026-10-20', 600, 660),
          true);
    });
    test('lapangan beda -> bebas', () {
      expect(hasConflict([_b(fieldId: 'L2')], 'L1', '2026-10-20', 600, 660),
          false);
    });
    test('tanggal beda -> bebas', () {
      expect(
          hasConflict(
              [_b(date: '2026-10-21')], 'L1', '2026-10-20', 600, 660),
          false);
    });
    test('jam bersentuhan -> bebas', () {
      expect(hasConflict([_b()], 'L1', '2026-10-20', 660, 720), false);
    });
  });

  group('slotStatuses', () {
    test('14 slot, default bebas', () {
      final m = slotStatuses([], 'L1', '2026-10-20');
      expect(m.length, 14);
      expect(m.values.every((s) => s == SlotStatus.free), true);
    });
    test('confirmed -> booked, pending -> pending', () {
      final m = slotStatuses(
        [_b(start: '10:00', end: '11:00', status: 'confirmed'),
         _b(start: '14:00', end: '15:00', status: 'pending')],
        'L1',
        '2026-10-20',
      );
      expect(m[10], SlotStatus.booked);
      expect(m[14], SlotStatus.pending);
      expect(m[11], SlotStatus.free);
    });
  });

  group('Booking.canCancel', () {
    test('3 hari ke depan, status pending -> bisa', () {
      // _b() default: 2026-10-20 10:00 (masa depan), status confirmed.
      expect(_b(status: 'pending').canCancel, true);
    });
    test('status cancelled -> tidak bisa', () {
      expect(_b(status: 'cancelled').canCancel, false);
    });
    test('status rejected -> tidak bisa', () {
      expect(_b(status: 'rejected').canCancel, false);
    });
  });
}
