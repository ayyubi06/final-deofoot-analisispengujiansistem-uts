import 'package:deofoot/models.dart';
import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('Field model', () {
    test('parses defaults, formats color, and builds photo asset path', () {
      final defaults = Field.fromMap('Padel-X', {});
      final parsed = Field.fromMap(
        'Padel-X',
        TestFixtures.fieldData(
          name: 'Padel Premium',
          pricePerHour: 240000,
          category: 'Padel',
          color: 0xff00ff00,
        )..['color'] = '#123456',
      );

      expect(defaults.name, 'Padel-X');
      expect(defaults.pricePerHour, 120000);
      expect(defaults.isActive, isTrue);
      expect(parsed.color.toARGB32(), 0xff123456);
      expect(parsed.toMap()['color'], 0xff123456);
      expect(parsed.photoAsset, 'assets/images/fields/padel-x.jpg');
      expect(
        Field.fromMap('f1', {'color': 0xffabcdef}).color.toARGB32(),
        0xffabcdef,
      );
      expect(
        Field.fromMap('f1', {'color': '#xyzxyz'}).color,
        defaults.color,
      );
    });

    test('reads and writes field documents through Firestore', () async {
      final db = TestFixtures.firestore();
      final service = FirestoreService(db: db);
      await TestFixtures.seedField(db, data: TestFixtures.fieldData());
      expect((await service.watchFields().first).single.name, 'Lapangan 1');

      final created = Field.fromMap(
        'field-2',
        TestFixtures.fieldData(name: 'Lapangan 2'),
      );
      await service.createField(created);
      await service.updateField(
        Field.fromMap('field-2', TestFixtures.fieldData(name: 'Lapangan Baru')),
      );
      await service.setFieldActive('field-2', false);
      final fields = await service.watchFields().first;
      expect(fields.map((field) => field.name), contains('Lapangan Baru'));
      expect(
        fields.singleWhere((field) => field.id == 'field-2').isActive,
        isFalse,
      );
    });
  });

  group('Booking model', () {
    test('parses full document, including optional series fields', () async {
      final db = TestFixtures.firestore();
      await TestFixtures.seedBooking(
        db,
        data: TestFixtures.bookingData(seriesId: 'series-1', seriesIndex: 2),
      );
      final doc = await db.collection('bookings').doc('booking-1').get();
      final booking = Booking.fromDoc(doc);

      expect(booking.id, 'booking-1');
      expect(booking.startMinutes, 19 * 60);
      expect(booking.endMinutes, 20 * 60);
      expect(booking.seriesId, 'series-1');
      expect(booking.seriesIndex, 2);
      expect(booking.createdAt, DateTime(2026, 11, 14, 8));
    });

    test('missing values use model defaults', () async {
      final db = TestFixtures.firestore();
      await db.collection('bookings').doc('empty').set({});
      final booking = Booking.fromDoc(
        await db.collection('bookings').doc('empty').get(),
      );
      expect(booking.userId, isEmpty);
      expect(booking.status, 'pending');
      expect(booking.totalPrice, 0);
      expect(booking.pricePerHour, 0);
      expect(booking.whatsapp, isEmpty);
    });

    test(
      'cancellation and upcoming flags follow status and start time',
      () async {
        final upcoming = DateTime.now().add(const Duration(hours: 4));
        final date = fmtDate(upcoming);
        final time =
            '${upcoming.hour.toString().padLeft(2, '0')}:'
            '${upcoming.minute.toString().padLeft(2, '0')}';
        final db = TestFixtures.firestore();
        await db
            .collection('bookings')
            .doc('future')
            .set(
              TestFixtures.bookingData(
                date: date,
                startTime: time,
                status: 'confirmed',
              ),
            );
        await db
            .collection('bookings')
            .doc('cancelled')
            .set(
              TestFixtures.bookingData(
                date: date,
                startTime: time,
                status: 'cancelled',
              ),
            );
        await db
            .collection('bookings')
            .doc('expired')
            .set(
              TestFixtures.bookingData(
                date: date,
                startTime: time,
                status: 'expired',
              ),
            );
        final confirmed = Booking.fromDoc(
          await db.collection('bookings').doc('future').get(),
        );
        final cancelled = Booking.fromDoc(
          await db.collection('bookings').doc('cancelled').get(),
        );
        final expired = Booking.fromDoc(
          await db.collection('bookings').doc('expired').get(),
        );
        expect(confirmed.canCancel, isTrue);
        expect(confirmed.isUpcoming, isTrue);
        expect(cancelled.canCancel, isFalse);
        expect(cancelled.isUpcoming, isFalse);
        expect(expired.isUpcoming, isFalse);
      },
    );
  });

  group('SubscriptionSeries model', () {
    test('parses dates and calculates the series total', () async {
      final db = TestFixtures.firestore();
      await TestFixtures.seedSeries(db);
      final series = SubscriptionSeries.fromDoc(
        await db.collection('subscriptions').doc('series-1').get(),
      );
      expect(series.meetingDates, ['2026-11-18', '2026-11-25']);
      expect(series.totalHarga, 240000);
      expect(series.cancelledMeetingDates, isEmpty);
    });

    test('missing fields and non-string date values are handled', () {
      final series = SubscriptionSeries.fromMap('s1', {
        'meetingDates': [1, '2026-11-25'],
        'cancelledMeetingDates': [2],
      });
      expect(series.meetingDates, ['1', '2026-11-25']);
      expect(series.cancelledMeetingDates, ['2']);
      expect(series.weekday, 1);
      expect(series.status, 'pending');
      expect(series.totalHarga, 0);
    });
  });
}
