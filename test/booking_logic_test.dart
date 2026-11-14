import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/models.dart';

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

/// Booking dengan waktu mulai relatif terhadap sekarang (anti basi).
Booking _bAt({
  Duration fromNow = const Duration(hours: 3),
  String status = 'pending',
}) {
  final dt = DateTime.now().add(fromNow);
  final time =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return Booking(
    id: 'x',
    userId: 'u',
    userEmail: 'u@x.id',
    fieldId: 'L1',
    fieldName: 'L1',
    date: fmtDate(dt),
    startTime: time,
    endTime: time,
    status: status,
    totalPrice: 120000,
    createdAt: DateTime.now(),
  );
}

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

  group('Booking.canCancel (tanggal relatif)', () {
    test('3 hari ke depan, status pending -> bisa', () {
      expect(
          _bAt(fromNow: const Duration(days: 3), status: 'pending')
              .canCancel,
          true);
    });
    test('lebih dari 2 jam (2j05m) -> bisa', () {
      expect(
          _bAt(
                  fromNow: const Duration(hours: 2, minutes: 5),
                  status: 'confirmed')
              .canCancel,
          true);
    });
    test('batas: tepat 2 jam -> TIDAK bisa', () {
      expect(
          _bAt(
                  fromNow: const Duration(hours: 2),
                  status: 'pending')
              .canCancel,
          false);
    });
    test('kurang dari 2 jam (1j59m) -> TIDAK bisa', () {
      expect(
          _bAt(
                  fromNow:
                      const Duration(hours: 1, minutes: 59),
                  status: 'pending')
              .canCancel,
          false);
    });
    test('status cancelled -> tidak bisa', () {
      expect(_bAt(status: 'cancelled').canCancel, false);
    });
    test('status rejected -> tidak bisa', () {
      expect(_bAt(status: 'rejected').canCancel, false);
    });
    test('status expired -> tidak bisa', () {
      expect(_bAt(status: 'expired').canCancel, false);
    });
  });

  group('status expired diperlakukan seperti cancelled/rejected', () {
    test('hasConflict mengabaikan expired', () {
      expect(
          hasConflict(
              [_b(status: 'expired')], 'L1', '2026-10-20', 600, 660),
          false);
    });
    test('slotStatuses mengabaikan expired', () {
      final m = slotStatuses(
        [_b(start: '10:00', end: '11:00', status: 'expired')],
        'L1',
        '2026-10-20',
      );
      expect(m[10], SlotStatus.free);
    });
    test('isUpcoming false untuk expired', () {
      expect(_bAt(status: 'expired').isUpcoming, false);
    });
  });

  group('slotStatuses multi-jam', () {
    test('booking 10:00-12:00 menandai jam 10 dan 11', () {
      final m = slotStatuses(
        [_b(start: '10:00', end: '12:00', status: 'confirmed')],
        'L1',
        '2026-10-20',
      );
      expect(m[10], SlotStatus.booked);
      expect(m[11], SlotStatus.booked);
      expect(m[12], SlotStatus.free);
    });
    test('booking pending 2 jam -> pending di kedua jam', () {
      final m = slotStatuses(
        [_b(start: '14:00', end: '16:00', status: 'pending')],
        'L1',
        '2026-10-20',
      );
      expect(m[14], SlotStatus.pending);
      expect(m[15], SlotStatus.pending);
    });
  });

  group('isValidWhatsapp', () {
    test('format 08 valid -> true', () {
      expect(isValidWhatsapp('081234567890'), true);
      expect(isValidWhatsapp(' 08123456789 '), true);
    });
    test('terlalu pendek / kosong -> false', () {
      expect(isValidWhatsapp(''), false);
      expect(isValidWhatsapp('08123'), false);
    });
    test('tidak diawali 08 / ada huruf -> false', () {
      expect(isValidWhatsapp('628123456789'), false);
      expect(isValidWhatsapp('08abc123456'), false);
    });
  });

group('toggleSlot (v0.3)', () {
  test('belum ada seleksi + tap bebas -> pilih 1 jam', () {
    final r = toggleSlot(const SlotSelection.empty(), 10, (_) => true);
    expect(r.start, 10);
    expect(r.end, 11);
    expect(r.hours, 1);
  });

  test('tap slot yang terpilih -> batal', () {
    final r = toggleSlot(const SlotSelection(10, 12), 11, (_) => true);
    expect(r.isEmpty, true);
  });

  test('tap bersebelahan -> perluas blok', () {
    var r = toggleSlot(const SlotSelection(10, 11), 11, (_) => true);
    expect(r.start, 10);
    expect(r.end, 12);
    r = toggleSlot(const SlotSelection(10, 12), 9, (_) => true);
    expect(r.start, 9);
    expect(r.end, 12);
  });

  test('tap tak bersebelahan (terhalang) -> mulai seleksi baru', () {
    final sel = const SlotSelection(10, 11);
    final r = toggleSlot(sel, 13, (h) => h != 12);
    expect(r.start, 13);
    expect(r.end, 14);
  });

  test('tap slot tak bisa dipilih -> seleksi tidak berubah', () {
    final sel = const SlotSelection(10, 11);
    final r = toggleSlot(sel, 13, (_) => false);
    expect(r.start, 10);
    expect(r.end, 11);
  });

  test('seleksi selalu satu blok berurutan', () {
    var sel = const SlotSelection.empty();
    sel = toggleSlot(sel, 14, (_) => true);
    sel = toggleSlot(sel, 15, (_) => true);
    sel = toggleSlot(sel, 16, (_) => true);
    expect(sel.hours, 3);
    expect(sel.contains(15), true);
    expect(sel.contains(13), false);
  });
});

group('bookingDateRange (v0.3, G6)', () {
  test('90 hari: hari ini -> H+89 (G6 berlaku sejak checkpoint Fase G)', () {
    final now = DateTime(2026, 10, 17, 15, 30);
    final days = bookingDateRange(now);
    expect(days.length, 90);
    expect(fmtDate(days.first), '2026-10-17');
    expect(fmtDate(days.last), '2027-01-14');
  });
});

group('isPastSlot (v0.3)', () {
  test('hari ini jam lewat -> true', () {
    final now = DateTime(2026, 10, 17, 14, 30);
    expect(isPastSlot(DateTime(2026, 10, 17), 13, now), true);
    expect(isPastSlot(DateTime(2026, 10, 17), 14, now), true);
  });

  test('hari ini jam depan -> false', () {
    final now = DateTime(2026, 10, 17, 14, 30);
    expect(isPastSlot(DateTime(2026, 10, 17), 15, now), false);
  });

  test('tanggal lain -> false', () {
    final now = DateTime(2026, 10, 17, 14, 30);
    expect(isPastSlot(DateTime(2026, 10, 18), 8, now), false);
  });
});

group('bookingTotal & Field dinamis (v0.3)', () {
  test('padel 1 jam @250rb = 250rb', () {
    expect(bookingTotal(1, 250000), 250000);
  });

  test('futsal 2 jam @120rb = 240rb', () {
    expect(bookingTotal(2, 120000), 240000);
  });

  test('Field.fromMap: field lengkap', () {
    final f = Field.fromMap('P1', {
      'name': 'Padel 1',
      'category': 'Padel',
      'pricePerHour': 250000,
      'color': 0xFF1D4ED8,
    });
    expect(f.category, 'Padel');
    expect(f.pricePerHour, 250000);
    expect(f.photoAsset, 'assets/images/fields/p1.jpg');
  });

  test('Field.fromMap: fallback bila field belum ada', () {
    final f = Field.fromMap('L9', {});
    expect(f.name, 'L9');
    expect(f.category, 'Futsal');
    expect(f.pricePerHour, 120000);
  });

  test('monthLabel', () {
    expect(monthLabel(DateTime(2026, 10, 17)), 'Okt');
    expect(monthLabel(DateTime(2026, 8, 1)), 'Agu');
  });
});

group('dayLabel', () {
  test('Senin dan Minggu', () {
    expect(dayLabel(DateTime(2026, 11, 16)), 'Sen');
    expect(dayLabel(DateTime(2026, 11, 15)), 'Min');
  });
});
}
