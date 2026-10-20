import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/notifications_logic.dart';

Booking _booking({
  String id = 'b1',
  String status = 'pending',
  String date = '2026-10-25',
  String startTime = '14:00',
  String endTime = '15:00',
  DateTime? createdAt,
}) {
  return Booking(
    id: id,
    userId: 'u1',
    userEmail: 'u@test.id',
    fieldId: 'l1',
    fieldName: 'Lapangan 1',
    date: date,
    startTime: startTime,
    endTime: endTime,
    status: status,
    totalPrice: 120000,
    createdAt: createdAt ?? DateTime(2026, 10, 21, 10, 0),
  );
}

// "Sekarang" acuan: Rabu 21 Okt 2026, 10:05.
final _now = DateTime(2026, 10, 21, 10, 5);

void main() {
  group('rencanaNotifikasi — pengingat bayar', () {
    test('pending baru → 1 rencana bayar pada createdAt+15 mnt', () {
      final r = rencanaNotifikasi(
        bookings: [_booking(createdAt: DateTime(2026, 10, 21, 10, 0))],
        now: _now,
      );
      expect(r.length, 1);
      expect(r.single.jenis, JenisPengingat.bayar);
      expect(r.single.waktu, DateTime(2026, 10, 21, 10, 15));
      expect(r.single.segera, isFalse);
      expect(r.single.judul, 'Selesaikan pembayaran booking');
      expect(r.single.isi, 'Lapangan 1 • 2026-10-25 • 14:00–15:00');
    });

    test('pending lewat batas 15 mnt → tidak ada pengingat susulan', () {
      final r = rencanaNotifikasi(
        bookings: [_booking(createdAt: DateTime(2026, 10, 21, 9, 0))],
        now: _now,
      );
      expect(r, isEmpty);
    });

    test('pending tapi waktu main sudah lewat → tidak dibuat', () {
      final r = rencanaNotifikasi(
        bookings: [
          _booking(
            date: '2026-10-21',
            startTime: '08:00',
            endTime: '09:00',
            createdAt: DateTime(2026, 10, 21, 10, 4),
          ),
        ],
        now: _now,
      );
      expect(r, isEmpty);
    });
  });

  group('rencanaNotifikasi — pengingat main', () {
    test('confirmed jauh → terjadwal mulai−2 jam', () {
      final r = rencanaNotifikasi(
        bookings: [_booking(status: 'confirmed')],
        now: _now,
      );
      expect(r.length, 1);
      expect(r.single.jenis, JenisPengingat.main);
      expect(r.single.waktu, DateTime(2026, 10, 25, 12, 0));
      expect(r.single.segera, isFalse);
      expect(r.single.judul, 'Pengingat main');
    });

    test('confirmed, titik −2 jam sudah lewat tapi main belum → segera', () {
      final r = rencanaNotifikasi(
        bookings: [
          _booking(
            status: 'confirmed',
            date: '2026-10-21',
            startTime: '11:00',
            endTime: '12:00',
          ),
        ],
        now: _now, // 10:05; titik pengingat 09:00 sudah lewat
      );
      expect(r.length, 1);
      expect(r.single.segera, isTrue);
    });

    test('confirmed tapi waktu main sudah lewat → tidak dibuat', () {
      final r = rencanaNotifikasi(
        bookings: [
          _booking(
            status: 'confirmed',
            date: '2026-10-21',
            startTime: '08:00',
            endTime: '09:00',
          ),
        ],
        now: _now,
      );
      expect(r, isEmpty);
    });

    test('status cancelled/rejected/expired → tidak ada rencana', () {
      for (final s in ['cancelled', 'rejected', 'expired']) {
        final r = rencanaNotifikasi(bookings: [_booking(status: s)], now: _now);
        expect(r, isEmpty, reason: 'status $s');
      }
    });
  });

  group('idNotifikasi', () {
    test('stabil, beda per jenis, beda per booking', () {
      final a1 = idNotifikasi('bookingA', JenisPengingat.bayar);
      final a2 = idNotifikasi('bookingA', JenisPengingat.bayar);
      final aMain = idNotifikasi('bookingA', JenisPengingat.main);
      final bBayar = idNotifikasi('bookingB', JenisPengingat.bayar);
      expect(a1, a2);
      expect(a1, isNot(aMain));
      expect(a1, isNot(bBayar));
      expect(a1, greaterThanOrEqualTo(0));
    });
  });

  group('rekonsiliasiNotifikasi', () {
    RencanaNotifikasi mk(int id, {bool segera = false}) => RencanaNotifikasi(
          id: id,
          bookingId: 'b$id',
          jenis: JenisPengingat.main,
          waktu: DateTime(2026, 10, 25, 12),
          segera: segera,
          judul: 'j',
          isi: 'i',
        );

    test('rencana baru → dijadwalkan; yatim → dibatalkan', () {
      final h = rekonsiliasiNotifikasi(
        rencana: [mk(1), mk(2)],
        idTerjadwal: {2, 99},
        idSudahTampil: {},
      );
      expect(h.jadwalkan.map((r) => r.id), [1]);
      expect(h.batalkan, [99]);
      expect(h.tampilkanSegera, isEmpty);
    });

    test('jalan kedua dengan rencana yang sama → tidak ada perubahan', () {
      final h = rekonsiliasiNotifikasi(
        rencana: [mk(1), mk(2)],
        idTerjadwal: {1, 2},
        idSudahTampil: {},
      );
      expect(h.jadwalkan, isEmpty);
      expect(h.batalkan, isEmpty);
      expect(h.tampilkanSegera, isEmpty);
    });

    test('segera belum tampil → ditampilkan; sudah tampil → tidak diulang', () {
      final belum = rekonsiliasiNotifikasi(
        rencana: [mk(7, segera: true)],
        idTerjadwal: {},
        idSudahTampil: {},
      );
      expect(belum.tampilkanSegera.map((r) => r.id), [7]);

      final sudah = rekonsiliasiNotifikasi(
        rencana: [mk(7, segera: true)],
        idTerjadwal: {},
        idSudahTampil: {7},
      );
      expect(sudah.tampilkanSegera, isEmpty);
    });
  });
}
