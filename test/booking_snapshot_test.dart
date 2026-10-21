import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';

// Test bukti snapshot (SPEK-V04 C5, rework T18): dokumen booking
// menyimpan fieldName + pricePerHour SEBAGAIMANA saat dibuat.
// Mengubah lapangan sesudahnya tidak boleh mengubah riwayat booking.
void main() {
  group('snapshot booking (C5)', () {
    test('booking mempertahankan nama & harga saat dibuat walau field '
        'diedit admin sesudahnya', () {
      // Lapangan saat booking dibuat.
      final fieldSaatBooking = Field(
        id: 'l1',
        name: 'Futsal Lama',
        pricePerHour: 100000,
      );
      // Booking dibuat dengan MENYALIN nama & harga dari lapangan —
      // persis yang dilakukan FirestoreService.createBooking.
      final booking = Booking(
        id: 'b1',
        userId: 'u1',
        userEmail: 'u@test.id',
        fieldId: fieldSaatBooking.id,
        fieldName: fieldSaatBooking.name,
        date: '2026-10-25',
        startTime: '19:00',
        endTime: '20:00',
        status: 'confirmed',
        totalPrice: 100000,
        pricePerHour: fieldSaatBooking.pricePerHour,
        createdAt: DateTime(2026, 10, 21, 10, 0),
      );

      // Admin mengedit lapangan yang sama: ganti nama + naikkan harga.
      final fieldSesudahEdit = Field(
        id: 'l1',
        name: 'Futsal Baru Premium',
        pricePerHour: 200000,
      );

      // Riwayat booking TIDAK berubah.
      expect(booking.fieldId, fieldSesudahEdit.id); // lapangan yang sama
      expect(booking.fieldName, 'Futsal Lama');
      expect(booking.fieldName, isNot(fieldSesudahEdit.name));
      expect(booking.pricePerHour, 100000);
      expect(booking.pricePerHour, isNot(fieldSesudahEdit.pricePerHour));
      expect(booking.totalPrice, 100000);
    });

    test('booking seri juga snapshot + membawa seriesIndex (E5)', () {
      final booking = Booking(
        id: 'b2',
        userId: 'u1',
        userEmail: 'u@test.id',
        fieldId: 'p1',
        fieldName: 'Padel 1',
        date: '2026-11-01',
        startTime: '19:00',
        endTime: '21:00',
        status: 'pending',
        totalPrice: 500000,
        pricePerHour: 250000,
        seriesId: 'seri1',
        seriesIndex: 3,
        createdAt: DateTime(2026, 10, 21, 10, 0),
      );
      expect(booking.seriesId, 'seri1');
      expect(booking.seriesIndex, 3);
    });
  });
}
