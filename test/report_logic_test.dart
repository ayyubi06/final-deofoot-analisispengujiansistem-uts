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
  });

  group('rentangPreset', () {
    // Rabu, 21 Oktober 2026.
    final now = DateTime(2026, 10, 21, 15, 30);

    test('hari ini', () {
      final (m, a) = rentangPreset(JenisRentang.hariIni, now);
      expect(m, DateTime(2026, 10, 21));
      expect(a, DateTime(2026, 10, 21));
    });

    test('minggu ini = Senin 19 s/d Minggu 25 Okt 2026', () {
      final (m, a) = rentangPreset(JenisRentang.mingguIni, now);
      expect(m, DateTime(2026, 10, 19));
      expect(a, DateTime(2026, 10, 25));
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
}
