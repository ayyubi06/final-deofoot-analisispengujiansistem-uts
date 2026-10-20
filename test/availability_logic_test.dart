import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/availability_logic.dart';

Field _f(String id, String name,
        {int open = 8, int close = 22, bool aktif = true}) =>
    Field(
      id: id,
      name: name,
      pricePerHour: 120000,
      isActive: aktif,
      openHour: open,
      closeHour: close,
    );

Booking _b(String fieldId, String start, String end,
        {String status = 'confirmed', String date = '2026-10-25'}) =>
    Booking(
      id: 'x$fieldId$start',
      userId: 'u1',
      userEmail: 'u@test.id',
      fieldId: fieldId,
      fieldName: fieldId,
      date: date,
      startTime: start,
      endTime: end,
      status: status,
      totalPrice: 120000,
      createdAt: DateTime(2026, 10, 20, 9),
    );

final _now = DateTime(2026, 10, 21, 9, 0); // sebelum tanggal uji (25 Okt)

List<SlotKosong> _cari({
  required List<Field> fields,
  Map<String, List<Booking>> bookings = const {},
  String tanggal = '2026-10-25',
  int durasi = 1,
  int mulai = 8,
  int selesai = 22,
  DateTime? now,
}) =>
    cariSlotKosong(
      fields: fields,
      bookingsPerField: bookings,
      tanggal: tanggal,
      durasiJam: durasi,
      jamMulai: mulai,
      jamSelesai: selesai,
      now: now ?? _now,
    );

void main() {
  group('cariSlotKosong', () {
    test('lapangan kosong → semua titik mulai dalam jendela', () {
      final r = _cari(fields: [_f('l1', 'Lapangan 1')], durasi: 2, mulai: 8, selesai: 12);
      expect(r.map((s) => s.startHour), [8, 9, 10]);
      expect(r.first.endHour, 10);
    });

    test('definisi terisi sama dengan Jadwal: tepi bersentuhan BUKAN konflik', () {
      // Terisi 10:00–12:00. Durasi 2, jendela 08–14:
      // mulai 8 (08–10, tepi) OK; 9,10,11 konflik; 12 (12–14, tepi) OK.
      final r = _cari(
        fields: [_f('l1', 'Lapangan 1')],
        bookings: {
          'l1': [_b('l1', '10:00', '12:00')],
        },
        durasi: 2,
        mulai: 8,
        selesai: 14,
      );
      expect(r.map((s) => s.startHour), [8, 12]);
    });

    test('pending menempati; cancelled/rejected/expired bebas', () {
      final r = _cari(
        fields: [_f('l1', 'Lapangan 1')],
        bookings: {
          'l1': [
            _b('l1', '10:00', '11:00', status: 'pending'),
            _b('l1', '12:00', '13:00', status: 'cancelled'),
            _b('l1', '14:00', '15:00', status: 'expired'),
          ],
        },
        mulai: 10,
        selesai: 15,
      );
      expect(r.map((s) => s.startHour), [11, 12, 13, 14]);
    });

    test('durasi tidak muat di renggang → tidak ditawarkan', () {
      // Bebas hanya 10–12 (2 jam); durasi 3 → nol hasil di jendela 8–14.
      final r = _cari(
        fields: [_f('l1', 'Lapangan 1')],
        bookings: {
          'l1': [
            _b('l1', '08:00', '10:00'),
            _b('l1', '12:00', '14:00'),
          ],
        },
        durasi: 3,
        mulai: 8,
        selesai: 14,
      );
      expect(r, isEmpty);
    });

    test('lapangan nonaktif dilewati', () {
      final r = _cari(fields: [
        _f('l1', 'Lapangan 1', aktif: false),
        _f('l2', 'Lapangan 2'),
      ], mulai: 8, selesai: 9);
      expect(r.map((s) => s.field.id), ['l2']);
    });

    test('jendela dipotong jam operasional lapangan', () {
      final r = _cari(
        fields: [_f('l1', 'Lapangan 1', open: 9, close: 21)],
        mulai: 6,
        selesai: 23,
      );
      expect(r.first.startHour, 9);
      expect(r.last.startHour, 20);
    });

    test('hari ini: slot yang sudah lewat tidak ditawarkan', () {
      final r = _cari(
        fields: [_f('l1', 'Lapangan 1')],
        tanggal: '2026-10-21',
        now: DateTime(2026, 10, 21, 13, 30),
        mulai: 8,
        selesai: 22,
      );
      expect(r.first.startHour, 14);
    });

    test('hasil terurut jam lalu nama lapangan', () {
      final r = _cari(fields: [
        _f('l2', 'Bravo'),
        _f('l1', 'Alpha'),
      ], mulai: 8, selesai: 10);
      expect(
        r.map((s) => '${s.startHour}-${s.field.name}'),
        ['8-Alpha', '8-Bravo', '9-Alpha', '9-Bravo'],
      );
    });
  });
}
