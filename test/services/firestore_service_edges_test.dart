import 'package:deofoot/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = TestFixtures.firestore();
    service = FirestoreService(db: db);
  });

  test(
    'uses the default account name when only the DANA number is stored',
    () async {
      await db.collection('config').doc('payment').set({
        'danaNumber': '089999999999',
      });

      expect(await service.getPaymentConfig(), {
        'danaNumber': '089999999999',
        'danaName': '-',
      });
    },
  );

  test('does not replace existing user document data', () async {
    const original = {
      'email': 'retained@example.test',
      'isAdmin': true,
      'note': 'existing',
    };
    await db.collection('users').doc('existing').set(original);

    await service.ensureUserDoc('existing', 'replacement@example.test');

    expect(
      (await db.collection('users').doc('existing').get()).data(),
      original,
    );
  });

  test(
    'all query streams return empty collections when there are no records',
    () async {
      expect(await service.watchFields().first, isEmpty);
      expect(
        await service.watchBookings('field-1', '2026-11-18').first,
        isEmpty,
      );
      expect(await service.watchBookingsByDate('2026-11-18').first, isEmpty);
      expect(await service.watchMyBookings('user-1').first, isEmpty);
      expect(await service.watchPending().first, isEmpty);
      expect(await service.watchMySeries('user-1').first, isEmpty);
      expect(await service.watchPendingSeries().first, isEmpty);
      expect(await service.watchBookingsBySeries('series-1').first, isEmpty);
    },
  );

  test('accepts a booking immediately after an occupied slot', () async {
    await TestFixtures.seedBooking(
      db,
      data: TestFixtures.bookingData(
        date: '2026-11-18',
        startTime: '09:00',
        endTime: '10:00',
      ),
    );

    await service.createBooking(
      userId: 'user-2',
      userEmail: 'other@example.test',
      fieldId: 'field-1',
      fieldName: 'Lapangan 1',
      date: '2026-11-18',
      startHour: 10,
      endHour: 11,
      whatsapp: '081234567890',
      proofBase64: 'encoded',
      totalPrice: 120000,
      pricePerHour: 120000,
    );

    expect((await db.collection('bookings').get()).docs, hasLength(2));
  });

  test('expires zero records if pending bookings are still recent', () async {
    await TestFixtures.seedBooking(
      db,
      data: TestFixtures.bookingData(
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );

    expect(await service.expireStalePendings(), 0);
  });

  test('rejects a series and its pending bookings in the same batch', () async {
    await TestFixtures.seedSeries(db);
    await TestFixtures.seedBooking(
      db,
      id: 'meeting',
      data: TestFixtures.bookingData(seriesId: 'series-1'),
    );

    await service.setSeriesStatus('series-1', 'rejected');

    expect(
      (await db.collection('subscriptions').doc('series-1').get())
          .data()?['status'],
      'rejected',
    );
    expect(
      (await db.collection('bookings').doc('meeting').get()).data()?['status'],
      'rejected',
    );
  });

  test('cancelled meeting dates are recorded only once', () async {
    await TestFixtures.seedSeries(db);
    await TestFixtures.seedBooking(
      db,
      id: 'meeting',
      data: TestFixtures.bookingData(seriesId: 'series-1'),
    );
    for (var i = 0; i < 2; i++) {
      await service.cancelSeriesMeeting(
        bookingId: 'meeting',
        seriesId: 'series-1',
        date: '2026-11-18',
      );
    }

    expect(
      (await db.collection('subscriptions').doc('series-1').get())
          .data()?['cancelledMeetingDates'],
      ['2026-11-18'],
    );
  });

  test('cancels the series with zero bookings left to cancel', () async {
    await TestFixtures.seedSeries(
      db,
      data: TestFixtures.seriesData(status: 'confirmed'),
    );
    await TestFixtures.seedBooking(
      db,
      id: 'pending',
      data: TestFixtures.bookingData(status: 'pending', seriesId: 'series-1'),
    );

    expect(await service.cancelRemainingSeries('series-1'), 0);
    expect(
      (await db.collection('subscriptions').doc('series-1').get())
          .data()?['status'],
      'cancelled',
    );
    expect(
      (await db.collection('bookings').doc('pending').get()).data()?['status'],
      'pending',
    );
  });

  test(
    'allows a series when existing bookings do not overlap its slots',
    () async {
      await TestFixtures.seedBooking(
        db,
        id: 'other-field',
        data: TestFixtures.bookingData(fieldId: 'field-2', date: '2026-11-18'),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'adjacent-time',
        data: TestFixtures.bookingData(
          date: '2026-11-25',
          startTime: '20:00',
          endTime: '21:00',
        ),
      );

      final id = await service.createSeries(
        userId: 'user-1',
        userEmail: 'user@example.test',
        fieldId: 'field-1',
        fieldName: 'Lapangan 1',
        meetingDates: ['2026-11-18', '2026-11-25'],
        startHour: 19,
        endHour: 20,
        whatsapp: '081234567890',
        proofBase64: 'encoded',
        pricePerHour: 120000,
      );

      expect((await service.watchBookingsBySeries(id).first), hasLength(2));
    },
  );

  test('returns an empty list for a date range without bookings', () async {
    expect(
      await service.watchBookingsInRange('2026-11-18', '2026-11-25').first,
      isEmpty,
    );
  });
}
