import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/recurring_logic.dart';

Booking _b(String date, String start, String end,
        {String status = 'confirmed', String fieldId = 'l1'}) =>
    Booking(
      id: 'x$date$start',
      userId: 'u1',
      userEmail: 'u@test.id',
      fieldId: fieldId,
      fieldName: 'Lapangan 1',
      date: date,
      startTime: start,
      endTime: end,
      status: status,
      totalPrice: 120000,
      seriesId: 'seri1',
      createdAt: DateTime(2026, 10, 20, 9),
    );

SubscriptionSeries _seri({
  String status = 'confirmed',
  List<String> dates = const ['2026-10-21', '2026-10-28'],
  String endTime = '15:00',
}) =>
    SubscriptionSeries.fromMap('seri1', {
      'userId': 'u1',
      'userEmail': 'u@test.id',
      'fieldId': 'l1',
      'fieldName': 'Lapangan 1',
      'weekday': 3,
      'startTime': '14:00',
      'endTime': endTime,
      'pricePerHour': 120000,
      'totalPerMeeting': 120000,
      'meetingsTotal': dates.length,
      'startDate': dates.first,
      'endDate': dates.last,
      'meetingDates': dates,
      'status': status,
    });

void main() {
  group('ekspansiTanggalSeri', () {
    test('4 pertemuan mingguan melintasi bulan', () {
      // Mulai Rabu 21 Okt 2026.
      expect(
        ekspansiTanggalSeri(DateTime(2026, 10, 21), 4),
        ['2026-10-21', '2026-10-28', '2026-11-04', '2026-11-11'],
      );
    });

    test('1 pertemuan = tanggal mulai saja; weekday konsisten', () {
      final t = ekspansiTanggalSeri(DateTime(2026, 10, 25), 3);
      expect(t, ['2026-10-25', '2026-11-01', '2026-11-08']);
      for (final s in t) {
        expect(DateTime.parse(s).weekday, DateTime.sunday);
      }
    });
  });

  group('totalHargaSeri', () {
    test('pertemuan × durasi × tarif', () {
      expect(
        totalHargaSeri(jumlahPertemuan: 8, durasiJam: 2, pricePerHour: 150000),
        2400000,
      );
      expect(
        totalHargaSeri(jumlahPertemuan: 4, durasiJam: 1, pricePerHour: 250000),
        1000000,
      );
    });
  });

  group('tanggalKonflikSeri (all-or-nothing)', () {
    final tanggal = ekspansiTanggalSeri(DateTime(2026, 10, 21), 4);

    test('satu tanggal bentrok → tanggal itu dilaporkan', () {
      final konflik = tanggalKonflikSeri(
        tanggalSeri: tanggal,
        bookingsPerTanggal: {
          '2026-10-28': [_b('2026-10-28', '14:00', '15:00')],
        },
        fieldId: 'l1',
        startMin: 14 * 60,
        endMin: 15 * 60,
      );
      expect(konflik, ['2026-10-28']);
    });

    test('booking pending juga bentrok; cancelled tidak; lapangan lain tidak', () {
      final konflik = tanggalKonflikSeri(
        tanggalSeri: tanggal,
        bookingsPerTanggal: {
          '2026-10-21': [_b('2026-10-21', '14:00', '15:00', status: 'pending')],
          '2026-10-28': [
            _b('2026-10-28', '14:00', '15:00', status: 'cancelled')
          ],
          '2026-11-04': [
            _b('2026-11-04', '14:00', '15:00', fieldId: 'l2')
          ],
        },
        fieldId: 'l1',
        startMin: 14 * 60,
        endMin: 15 * 60,
      );
      expect(konflik, ['2026-10-21']);
    });

    test('tepi bersentuhan bukan konflik → seri aman', () {
      final konflik = tanggalKonflikSeri(
        tanggalSeri: tanggal,
        bookingsPerTanggal: {
          '2026-10-21': [_b('2026-10-21', '15:00', '16:00')],
        },
        fieldId: 'l1',
        startMin: 14 * 60,
        endMin: 15 * 60,
      );
      expect(konflik, isEmpty);
    });
  });

  group('statusSeriEfektif & label', () {
    test('confirmed dan masih ada pertemuan depan → Aktif', () {
      final s = _seri();
      expect(statusSeriEfektif(s, DateTime(2026, 10, 22)), 'confirmed');
      expect(labelStatusSeri('confirmed'), 'Aktif');
    });

    test('confirmed dan pertemuan terakhir sudah berakhir → Selesai', () {
      final s = _seri();
      // Pertemuan terakhir 28 Okt 15:00; now 29 Okt.
      expect(statusSeriEfektif(s, DateTime(2026, 10, 29)), 'selesai');
      expect(labelStatusSeri('selesai'), 'Selesai');
    });

    test('pending tetap pending walau tanggal lewat', () {
      final s = _seri(status: 'pending');
      expect(statusSeriEfektif(s, DateTime(2026, 12, 1)), 'pending');
      expect(labelStatusSeri('pending'), 'Menunggu verifikasi');
    });
  });

  group('sisaPertemuan (batalkan sisa seri, spek E7)', () {
    test('hanya confirmed mendatang — pending TIDAK ikut (rework T12)', () {
      final now = DateTime(2026, 10, 22, 10, 0);
      final sisa = sisaPertemuan([
        _b('2026-10-21', '14:00', '15:00'), // sudah lewat
        _b('2026-10-28', '14:00', '15:00'), // depan, confirmed → sisa
        _b('2026-11-04', '14:00', '15:00', status: 'pending'), // BUKAN sisa
        _b('2026-11-11', '14:00', '15:00', status: 'cancelled'), // sudah batal
      ], now);
      expect(sisa.map((b) => b.date), ['2026-10-28']);
    });
  });

  group('tanggalPertamaUntukHari (form seri E2)', () {
    // Rabu, 21 Oktober 2026.
    final rabu = DateTime(2026, 10, 21);

    test('besok tepat hari terpilih → besok', () {
      // Kamis = weekday 4.
      expect(tanggalPertamaUntukHari(4, rabu), DateTime(2026, 10, 22));
    });

    test('hari terpilih = hari ini → kemunculan berikutnya (+7)', () {
      // Rabu = weekday 3; mulai besok → Rabu pekan depan.
      expect(tanggalPertamaUntukHari(3, rabu), DateTime(2026, 10, 28));
    });

    test('hari terpilih sudah lewat pekan ini → pekan depan', () {
      // Selasa = weekday 2 (kemarin) → Selasa 27 Okt.
      expect(tanggalPertamaUntukHari(2, rabu), DateTime(2026, 10, 27));
    });

    test('hasil selalu hari yang dipilih & sesudah hari ini', () {
      for (var wd = 1; wd <= 7; wd++) {
        final t = tanggalPertamaUntukHari(wd, rabu);
        expect(t.weekday, wd);
        expect(t.isAfter(rabu), isTrue);
      }
    });
  });

  group('SubscriptionSeries.fromMap', () {
    test('parse field seri termasuk daftar tanggal', () {
      final s = _seri();
      expect(s.weekday, 3);
      expect(s.meetingDates, ['2026-10-21', '2026-10-28']);
      expect(s.totalHarga, 240000);
      expect(s.cancelledMeetingDates, isEmpty);
    });
  });
}
