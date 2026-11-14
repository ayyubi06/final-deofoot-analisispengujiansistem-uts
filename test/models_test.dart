import 'package:deofoot/models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fase2_helpers.dart';

void main() {
  late FakeFirebaseFirestore fake;

  setUp(() {
    fake = FakeFirebaseFirestore();
  });

  group('Field', () {
    test('fromDoc membaca dokumen Firestore', () async {
      await seedField(fake, id: 'l1', name: 'Lapangan 1', price: 150000);
      final snap = await fake.collection('fields').doc('l1').get();
      final f = Field.fromDoc(snap);
      expect(f.id, 'l1');
      expect(f.name, 'Lapangan 1');
      expect(f.pricePerHour, 150000);
      expect(f.isActive, true);
    });

    test('warna string "#RRGGBB" dan "RRGGBB" diparse', () {
      final a = Field.fromMap('x', {'color': '#336699'});
      expect(a.color, const Color(0xFF336699));
      final b = Field.fromMap('x', {'color': '336699'});
      expect(b.color, const Color(0xFF336699));
    });

    test('warna tidak dikenali -> fallback navy', () {
      final a = Field.fromMap('x', {'color': 'bukan-warna'});
      expect(a.color, isNot(const Color(0xFF336699)));
      final b = Field.fromMap('x', {});
      expect(b.color, a.color);
    });
  });

  group('Booking', () {
    test('fromDoc membaca dokumen lengkap', () async {
      await seedBooking(fake, id: 'b1', status: 'confirmed');
      final snap = await fake.collection('bookings').doc('b1').get();
      final b = Booking.fromDoc(snap);
      expect(b.id, 'b1');
      expect(b.status, 'confirmed');
      expect(b.totalPrice, 120000);
      expect(b.seriesId, isNull);
    });

    test('fromDoc dokumen kosong -> nilai bawaan', () async {
      await fake.collection('bookings').doc('b0').set({});
      final snap = await fake.collection('bookings').doc('b0').get();
      final b = Booking.fromDoc(snap);
      expect(b.status, 'pending');
      expect(b.totalPrice, 0);
      expect(b.userId, '');
    });

    test('isUpcoming true untuk booking mendatang', () {
      final b = Booking(
        id: 'b1',
        userId: 'u1',
        userEmail: 'u@test.com',
        fieldId: 'l1',
        fieldName: 'Lapangan 1',
        date: '2099-01-01',
        startTime: '19:00',
        endTime: '20:00',
        status: 'pending',
        totalPrice: 120000,
        createdAt: DateTime.now(),
      );
      expect(b.isUpcoming, true);
    });
  });

  group('SubscriptionSeries', () {
    test('fromDoc membaca dokumen seri', () async {
      await seedSeries(fake, id: 's1', status: 'confirmed');
      final snap = await fake.collection('subscriptions').doc('s1').get();
      final s = SubscriptionSeries.fromDoc(snap);
      expect(s.id, 's1');
      expect(s.status, 'confirmed');
      expect(s.meetingsTotal, 2);
      expect(s.totalHarga, 240000);
    });
  });
}
