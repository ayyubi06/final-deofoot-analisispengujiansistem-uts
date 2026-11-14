import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/report_logic.dart';

Booking _b({
  String id = 'b1',
  String status = 'confirmed',
  String fieldId = 'l1',
  String fieldName = 'Lapangan 1',
  String date = '2026-10-21',
  String startTime = '14:00',
  String endTime = '15:00',
  int totalPrice = 120000,
}) {
  return Booking(
    id: id,
    userId: 'u1',
    userEmail: 'u@test.id',
    fieldId: fieldId,
    fieldName: fieldName,
    date: date,
    startTime: startTime,
    endTime: endTime,
    status: status,
    totalPrice: totalPrice,
    createdAt: DateTime(2026, 10, 20, 9, 0),
  );
}

void main() {
  group('hitungLaporan', () {
    test('hanya confirmed yang terhitung (pendapatan, jumlah, slot)', () {
      final lap = hitungLaporan(
        [
          _b(id: 'a'), // confirmed 1 jam 120rb
          _b(id: 'b', status: 'pending', totalPrice: 999000),
          _b(id: 'c', status: 'cancelled', totalPrice: 888000),
          _b(id: 'd', status: 'rejected', totalPrice: 777000),
          _b(id: 'e', status: 'expired', totalPrice: 666000),
        ],
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 21),
      );
      expect(lap.jumlahBooking, 1);
      expect(lap.slotTerisi, 1);
      expect(lap.pendapatan, 120000);
    });

    test('booking multi-jam menyumbang semua jamnya; rentang inklusif', () {
      final lap = hitungLaporan(
        [
          _b(id: 'a', date: '2026-10-19', startTime: '08:00', endTime: '11:00', totalPrice: 360000),
          _b(id: 'b', date: '2026-10-25', startTime: '19:00', endTime: '20:00', totalPrice: 120000),
          _b(id: 'c', date: '2026-10-26', totalPrice: 555000), // di luar rentang
          _b(id: 'd', date: '2026-10-18', totalPrice: 444000), // di luar rentang
        ],
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 25),
      );
      expect(lap.jumlahBooking, 2);
      expect(lap.slotTerisi, 4);
      expect(lap.pendapatan, 480000);
      expect(lap.pendapatanPerTanggal['2026-10-19'], 360000);
      expect(lap.bookingPerTanggal['2026-10-25'], 1);
    });

    test('per lapangan teragregasi dan terurut pendapatan desc', () {
      final lap = hitungLaporan(
        [
          _b(id: 'a', fieldId: 'l1', fieldName: 'Lapangan 1', totalPrice: 120000),
          _b(id: 'b', fieldId: 'p1', fieldName: 'Padel 1', totalPrice: 250000),
          _b(id: 'c', fieldId: 'l1', fieldName: 'Lapangan 1', totalPrice: 120000),
        ],
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 21),
      );
      expect(lap.perLapangan.length, 2);
      expect(lap.perLapangan.first.fieldId, 'p1');
      expect(lap.perLapangan.first.pendapatan, 250000);
      expect(lap.perLapangan.last.fieldId, 'l1');
      expect(lap.perLapangan.last.jumlahBooking, 2);
      expect(lap.perLapangan.last.pendapatan, 240000);
    });

    test('daftar kosong → semua nol', () {
      final lap = hitungLaporan(
          const [], DateTime(2026, 10, 21), DateTime(2026, 10, 21));
      expect(lap.jumlahBooking, 0);
      expect(lap.slotTerisi, 0);
      expect(lap.pendapatan, 0);
      expect(lap.perLapangan, isEmpty);
    });

    test('jumlah per status (B3): semua status dalam periode terhitung',
        () {
      final lap = hitungLaporan(
        [
          _b(id: 'a'),
          _b(id: 'b', status: 'pending'),
          _b(id: 'c', status: 'pending'),
          _b(id: 'd', status: 'cancelled'),
          _b(id: 'e', status: 'rejected'),
          _b(id: 'f', status: 'expired'),
          _b(id: 'g', status: 'pending', date: '2026-10-22'), // luar rentang
        ],
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 21),
      );
      expect(lap.jumlahPerStatus['confirmed'], 1);
      expect(lap.jumlahPerStatus['pending'], 2);
      expect(lap.jumlahPerStatus['cancelled'], 1);
      expect(lap.jumlahPerStatus['rejected'], 1);
      expect(lap.jumlahPerStatus['expired'], 1);
    });

    test('okupansi per lapangan (B3): slot ÷ (14 × hari) persen', () {
      // 7 slot terisi dalam periode 1 hari → 7/14 = 50%.
      final lap = hitungLaporan(
        [
          _b(
              id: 'a',
              startTime: '08:00',
              endTime: '15:00',
              totalPrice: 840000),
        ],
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 21),
      );
      expect(lap.jumlahHari, 1);
      expect(lap.perLapangan.single.slotTerisi, 7);
      expect(lap.perLapangan.single.okupansiPersen, closeTo(50.0, 0.001));

      // 2 slot dalam periode 7 hari → 2/98 ≈ 2,04%.
      final lap7 = hitungLaporan(
        [_b(id: 'a', startTime: '19:00', endTime: '21:00')],
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 25),
      );
      expect(lap7.jumlahHari, 7);
      expect(
          lap7.perLapangan.single.okupansiPersen, closeTo(2.0408, 0.001));
    });
  });

  group('rentangPreset', () {
    // Rabu, 21 Oktober 2026.
    final now = DateTime(2026, 10, 21, 15, 30);

    test('hari ini', () {
      final (m, a) = rentangPreset(JenisRentang.hariIni, now);
      expect(m, DateTime(2026, 10, 21));
      expect(a, DateTime(2026, 10, 21));
    });

    test('7 hari terakhir = bergulir hari ini + 6 hari sebelumnya (B2)',
        () {
      final (m, a) = rentangPreset(JenisRentang.tujuhHariTerakhir, now);
      expect(m, DateTime(2026, 10, 15));
      expect(a, DateTime(2026, 10, 21));
    });

    test('7 hari terakhir melintasi pergantian bulan', () {
      final (m, a) = rentangPreset(
          JenisRentang.tujuhHariTerakhir, DateTime(2026, 11, 2, 9, 0));
      expect(m, DateTime(2026, 10, 27));
      expect(a, DateTime(2026, 11, 2));
    });

    test('bulan ini = 1 s/d 31 Okt 2026', () {
      final (m, a) = rentangPreset(JenisRentang.bulanIni, now);
      expect(m, DateTime(2026, 10, 1));
      expect(a, DateTime(2026, 10, 31));
    });
  });

  group('tanggalIndonesia', () {
    test('format panjang dengan nama hari & bulan', () {
      expect(tanggalIndonesia(DateTime(2026, 10, 21)),
          'Rabu, 21 Oktober 2026');
      expect(tanggalIndonesia(DateTime(2026, 10, 25)),
          'Minggu, 25 Oktober 2026');
      expect(namaBulan(1), 'Januari');
      expect(namaBulan(12), 'Desember');
    });
  });

  group('rentangPreset pilihan', () {
    test('pilihan mengembalikan (hari ini, hari ini)', () {
      final (mulai, akhir) =
          rentangPreset(JenisRentang.pilihan, DateTime(2026, 11, 14, 15, 30));
      expect(mulai, DateTime(2026, 11, 14));
      expect(akhir, DateTime(2026, 11, 14));
    });
  });
}
