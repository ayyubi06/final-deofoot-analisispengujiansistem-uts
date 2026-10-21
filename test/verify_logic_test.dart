import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/verify_logic.dart';
import 'package:deofoot/models.dart';

Booking _b(String id, {String? seriesId, String status = 'pending'}) =>
    Booking(
      id: id,
      userId: 'u1',
      userEmail: 'a@test.id',
      fieldId: 'l1',
      fieldName: 'Futsal L1',
      date: '2026-11-02',
      startTime: '19:00',
      endTime: '20:00',
      status: status,
      totalPrice: 120000,
      seriesId: seriesId,
      createdAt: DateTime(2026, 10, 21),
    );

void main() {
  group('bookingVerifikasiIndividual (Addendum 4 — test DoD a)', () {
    test('booking berseriesId TIDAK muncul di daftar verifikasi', () {
      final hasil = bookingVerifikasiIndividual([
        _b('biasa1'),
        _b('seri1', seriesId: 'seriA'),
        _b('biasa2'),
        _b('seri2', seriesId: 'seriA'),
      ]);
      expect(hasil.map((b) => b.id), ['biasa1', 'biasa2']);
    });

    test('semua seri -> daftar individual kosong', () {
      expect(
        bookingVerifikasiIndividual([_b('s1', seriesId: 'x')]),
        isEmpty,
      );
    });

    test('daftar kosong -> kosong', () {
      expect(bookingVerifikasiIndividual(const []), isEmpty);
    });
  });

  group('dampak keputusan seri (semantik setSeriesStatus)', () {
    final meetings = [
      _b('m1', seriesId: 'seriA'),
      _b('m2', seriesId: 'seriA'),
      _b('m3', seriesId: 'seriA', status: 'cancelled'),
      _b('m4', seriesId: 'seriA', status: 'confirmed'),
    ];

    test('yang ikut berubah hanya yang pending', () {
      expect(jumlahPertemuanIkutBerubah(meetings), 2);
    });

    test('yang tidak berubah: cancelled + confirmed (DoD c, sisi data)',
        () {
      expect(
        pertemuanTidakBerubah(meetings).map((b) => b.id),
        ['m3', 'm4'],
      );
    });
  });

  group('pertemuanSeriUrut', () {
    test('terurut tanggal lalu jam', () {
      final hasil = pertemuanSeriUrut([
        _b('c', seriesId: 's'),
        Booking(
          id: 'a',
          userId: 'u1',
          userEmail: 'a@test.id',
          fieldId: 'l1',
          fieldName: 'Futsal L1',
          date: '2026-10-26',
          startTime: '19:00',
          endTime: '20:00',
          status: 'pending',
          totalPrice: 120000,
          seriesId: 's',
          createdAt: DateTime(2026, 10, 21),
        ),
        Booking(
          id: 'b',
          userId: 'u1',
          userEmail: 'a@test.id',
          fieldId: 'l1',
          fieldName: 'Futsal L1',
          date: '2026-11-02',
          startTime: '08:00',
          endTime: '09:00',
          status: 'pending',
          totalPrice: 120000,
          seriesId: 's',
          createdAt: DateTime(2026, 10, 21),
        ),
      ]);
      // a: 26 Okt; b: 2 Nov 08:00; c: 2 Nov 19:00
      expect(hasil.map((b) => b.id), ['a', 'b', 'c']);
    });
  });
}
