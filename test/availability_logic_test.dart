import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/availability_logic.dart';

Field _f(String id, String name, {bool aktif = true}) => Field(
      id: id,
      name: name,
      pricePerHour: 120000,
      isActive: aktif,
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

List<Field> _bebas({
  required List<Field> fields,
  List<Booking> bookings = const [],
  String tanggal = '2026-10-25',
  int jamMulai = 19,
  int durasi = 1,
}) =>
    lapanganBebas(
      fields: fields,
      bookings: bookings,
      tanggal: tanggal,
      jamMulai: jamMulai,
      durasiJam: durasi,
    );

void main() {
  group('lapanganBebas (spek D: satu jam mulai + durasi → daftar lapangan)',
      () {
    test('lapangan kosong pada rentang pilihan → termasuk hasil', () {
      final r = _bebas(fields: [_f('l1', 'Lapangan 1')]);
      expect(r.map((f) => f.id), ['l1']);
    });

    test('bentrok confirmed → tersisih; tepi bersentuhan → tetap bebas',
        () {
      // Terisi 19:00–20:00 di l1.
      final bookings = [_b('l1', '19:00', '20:00')];
      // Rentang 19–20 persis menabrak.
      expect(
        _bebas(fields: [_f('l1', 'Lapangan 1')], bookings: bookings),
        isEmpty,
      );
      // Rentang 20–21 hanya bersentuhan di tepi → bebas.
      final tepi = _bebas(
        fields: [_f('l1', 'Lapangan 1')],
        bookings: bookings,
        jamMulai: 20,
      );
      expect(tepi.map((f) => f.id), ['l1']);
    });

    test('pending menempati; cancelled/rejected/expired bebas', () {
      final fields = [_f('l1', 'Lapangan 1')];
      expect(
        _bebas(
            fields: fields,
            bookings: [_b('l1', '19:00', '20:00', status: 'pending')]),
        isEmpty,
      );
      for (final s in ['cancelled', 'rejected', 'expired']) {
        final r = _bebas(
            fields: fields,
            bookings: [_b('l1', '19:00', '20:00', status: s)]);
        expect(r.length, 1, reason: 'status $s harus bebas');
      }
    });

    test('durasi 4 jam (maksimum spek) didukung', () {
      final r = _bebas(
        fields: [_f('l1', 'Lapangan 1')],
        jamMulai: 8,
        durasi: 4,
      );
      expect(r.map((f) => f.id), ['l1']);
      // Rentang yang sebagian tertabrak di tengah → tersisih.
      final tabrak = _bebas(
        fields: [_f('l1', 'Lapangan 1')],
        bookings: [_b('l1', '10:00', '11:00')],
        jamMulai: 8,
        durasi: 4,
      );
      expect(tabrak, isEmpty);
    });

    test('rentang keluar grid global 08–22 → kosong', () {
      final fields = [_f('l1', 'Lapangan 1')];
      expect(_bebas(fields: fields, jamMulai: 7), isEmpty);
      expect(_bebas(fields: fields, jamMulai: 20, durasi: 3), isEmpty);
      expect(_bebas(fields: fields, durasi: 5), isEmpty);
      expect(_bebas(fields: fields, durasi: 0), isEmpty);
    });

    test('lapangan nonaktif dikecualikan; hasil terurut nama', () {
      final r = _bebas(fields: [
        _f('l2', 'Bravo'),
        _f('l3', 'Charlie', aktif: false),
        _f('l1', 'Alpha'),
      ]);
      expect(r.map((f) => f.name), ['Alpha', 'Bravo']);
    });

    test('campuran: hanya lapangan yang bebas seluruh rentang', () {
      final r = _bebas(
        fields: [_f('l1', 'Alpha'), _f('l2', 'Bravo')],
        bookings: [_b('l2', '19:00', '21:00')],
        durasi: 2,
      );
      expect(r.map((f) => f.id), ['l1']);
    });
  });
}
