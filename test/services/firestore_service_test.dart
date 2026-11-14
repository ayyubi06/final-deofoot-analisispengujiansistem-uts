import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/models.dart';
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

  group('field and account access', () {
    test('returns fields and supports admin field writes', () async {
      await TestFixtures.seedField(db);
      expect((await service.watchFields().first).single.id, 'field-1');

      final field = Field.fromMap(
        'field-2',
        TestFixtures.fieldData(name: 'Lapangan Baru'),
      );
      await service.createField(field);
      await service.updateField(
        Field.fromMap(
          'field-2',
          TestFixtures.fieldData(name: 'Lapangan Update', pricePerHour: 150000),
        ),
      );
      await service.setFieldActive('field-2', false);

      final updated = (await service.watchFields().first).singleWhere(
        (item) => item.id == 'field-2',
      );
      expect(updated.name, 'Lapangan Update');
      expect(updated.pricePerHour, 150000);
      expect(updated.isActive, isFalse);
    });

    test(
      'reads payment config and supplies defaults for absent values',
      () async {
        expect(await service.getPaymentConfig(), {
          'danaNumber': '-',
          'danaName': '-',
        });
        await TestFixtures.seedPaymentConfig(db);
        expect(await service.getPaymentConfig(), {
          'danaNumber': '081234567890',
          'danaName': 'Deofoot',
        });
      },
    );

    test('checks admin status and creates a user document only once', () async {
      expect(await service.isAdmin('new-user'), isFalse);
      await service.ensureUserDoc('new-user', 'new@example.test');
      expect(await service.isAdmin('new-user'), isFalse);

      await db.collection('users').doc('admin').set({'isAdmin': true});
      expect(await service.isAdmin('admin'), isTrue);
      await service.ensureUserDoc('admin', 'changed@example.test');
      expect(
        (await db.collection('users').doc('admin').get()).data()?['email'],
        isNull,
      );
      expect(
        (await db.collection('users').doc('new-user').get()).data()?['email'],
        'new@example.test',
      );
    });
  });

  group('booking queries', () {
    test('filters by field and date, or by date across all fields', () async {
      await TestFixtures.seedBooking(db, id: 'target');
      await TestFixtures.seedBooking(
        db,
        id: 'other-field',
        data: TestFixtures.bookingData(fieldId: 'field-2'),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'other-day',
        data: TestFixtures.bookingData(date: '2026-11-19'),
      );

      expect(
        (await service.watchBookings('field-1', '2026-11-18').first).map(
          (item) => item.id,
        ),
        ['target'],
      );
      expect(
        (await service.watchBookingsByDate('2026-11-18').first).map(
          (item) => item.id,
        ),
        containsAll(['target', 'other-field']),
      );
    });

    test('sorts user bookings newest first and pending oldest first', () async {
      await TestFixtures.seedBooking(
        db,
        id: 'older',
        data: TestFixtures.bookingData(createdAt: DateTime(2026, 11, 12)),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'newer',
        data: TestFixtures.bookingData(createdAt: DateTime(2026, 11, 13)),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'different-user',
        data: TestFixtures.bookingData(userId: 'user-2'),
      );

      expect(
        (await service.watchMyBookings('user-1').first).map((item) => item.id),
        ['newer', 'older'],
      );
      expect((await service.watchPending().first).map((item) => item.id), [
        'older',
        'newer',
        'different-user',
      ]);
    });

    test('queries inclusive report ranges and today bookings', () async {
      await TestFixtures.seedBooking(
        db,
        id: 'inside-start',
        data: TestFixtures.bookingData(date: '2026-11-17'),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'inside-end',
        data: TestFixtures.bookingData(date: '2026-11-19'),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'outside',
        data: TestFixtures.bookingData(date: '2026-11-20'),
      );
      final today = fmtDate(DateTime.now());
      await TestFixtures.seedBooking(
        db,
        id: 'today',
        data: TestFixtures.bookingData(date: today),
      );

      expect(
        (await service.watchBookingsInRange('2026-11-17', '2026-11-19').first)
            .map((item) => item.id),
        containsAll(['inside-start', 'inside-end']),
      );
      expect(
        (await service.watchBookingsToday().first).map((item) => item.id),
        ['today'],
      );
    });
  });

  group('single booking mutations', () {
    test('creates a booking with snapshot fields in a transaction', () async {
      final id = await service.createBooking(
        userId: 'user-1',
        userEmail: 'user@example.test',
        fieldId: 'field-1',
        fieldName: 'Lapangan 1',
        date: '2026-11-18',
        startHour: 9,
        endHour: 11,
        whatsapp: '081234567890',
        proofBase64: 'encoded',
        totalPrice: 240000,
        pricePerHour: 120000,
      );
      final booking = Booking.fromDoc(
        await db.collection('bookings').doc(id).get(),
      );
      expect(booking.startTime, '09:00');
      expect(booking.endTime, '11:00');
      expect(booking.status, 'pending');
      expect(booking.totalPrice, 240000);
      expect(booking.pricePerHour, 120000);
    });

    test('rejects a conflicting booking without writing a document', () async {
      await TestFixtures.seedBooking(
        db,
        data: TestFixtures.bookingData(
          date: '2026-11-18',
          startTime: '09:00',
          endTime: '10:00',
        ),
      );
      await expectLater(
        service.createBooking(
          userId: 'user-2',
          userEmail: 'other@example.test',
          fieldId: 'field-1',
          fieldName: 'Lapangan 1',
          date: '2026-11-18',
          startHour: 9,
          endHour: 10,
          whatsapp: '081234567890',
          proofBase64: 'encoded',
          totalPrice: 120000,
          pricePerHour: 120000,
        ),
        throwsA(isA<BookingConflictException>()),
      );
      expect((await db.collection('bookings').get()).docs, hasLength(1));
    });

    test('expires only pending bookings older than thirty minutes', () async {
      await TestFixtures.seedBooking(
        db,
        id: 'stale',
        data: TestFixtures.bookingData(
          createdAt: DateTime.now().subtract(const Duration(minutes: 31)),
        ),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'recent',
        data: TestFixtures.bookingData(
          createdAt: DateTime.now().subtract(const Duration(minutes: 29)),
        ),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'confirmed',
        data: TestFixtures.bookingData(
          status: 'confirmed',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'no-timestamp',
        data: TestFixtures.bookingData()..remove('createdAt'),
      );

      expect(await service.expireStalePendings(), 1);
      expect(
        (await db.collection('bookings').doc('stale').get()).data()?['status'],
        'expired',
      );
      expect(
        (await db.collection('bookings').doc('recent').get()).data()?['status'],
        'pending',
      );
    });

    test('cancels bookings and restricts admin status values', () async {
      await TestFixtures.seedBooking(db);
      await service.cancelBooking('booking-1');
      expect(
        (await db.collection('bookings').doc('booking-1').get())
            .data()?['status'],
        'cancelled',
      );
      await service.setBookingStatus('booking-1', 'confirmed');
      expect(
        (await db.collection('bookings').doc('booking-1').get())
            .data()?['status'],
        'confirmed',
      );
      await service.setBookingStatus('booking-1', 'rejected');
      await expectLater(
        service.setBookingStatus('booking-1', 'pending'),
        throwsArgumentError,
      );
    });
  });

  test('conflict exceptions expose useful messages', () {
    final bookingConflict = BookingConflictException('Slot sudah terisi.');
    expect(bookingConflict.toString(), 'Slot sudah terisi.');

    final seriesConflict = SeriesConflictException([
      '2026-11-18',
      '2026-11-25',
    ]);
    expect(
      seriesConflict.message,
      'Slot bentrok pada 2 tanggal: 2026-11-18, 2026-11-25',
    );
    expect(seriesConflict.toString(), seriesConflict.message);
  });

  group('subscription series', () {
    test('queries user and pending series in their specified order', () async {
      await TestFixtures.seedSeries(
        db,
        id: 'old',
        data: TestFixtures.seriesData(createdAt: DateTime(2026, 11, 12)),
      );
      await TestFixtures.seedSeries(
        db,
        id: 'new',
        data: TestFixtures.seriesData(createdAt: DateTime(2026, 11, 13)),
      );
      await TestFixtures.seedSeries(
        db,
        id: 'other-user',
        data: TestFixtures.seriesData(userId: 'user-2'),
      );

      expect(
        (await service.watchMySeries('user-1').first).map((item) => item.id),
        ['new', 'old'],
      );
      expect(
        (await service.watchPendingSeries().first).map((item) => item.id),
        ['old', 'new', 'other-user'],
      );
    });

    test('queries bookings attached to a series', () async {
      await TestFixtures.seedBooking(
        db,
        id: 'series-booking',
        data: TestFixtures.bookingData(seriesId: 'series-1'),
      );
      await TestFixtures.seedBooking(db, id: 'regular-booking');
      expect(
        (await service.watchBookingsBySeries('series-1').first).map(
          (item) => item.id,
        ),
        ['series-booking'],
      );
    });

    test('creates a series and meeting bookings atomically', () async {
      final dates = ['2026-11-18', '2026-11-25'];
      final id = await service.createSeries(
        userId: 'user-1',
        userEmail: 'user@example.test',
        fieldId: 'field-1',
        fieldName: 'Lapangan 1',
        meetingDates: dates,
        startHour: 19,
        endHour: 21,
        whatsapp: '081234567890',
        proofBase64: 'encoded',
        pricePerHour: 120000,
      );

      final series = SubscriptionSeries.fromDoc(
        await db.collection('subscriptions').doc(id).get(),
      );
      final bookings = (await service.watchBookingsBySeries(id).first)
        ..sort((a, b) => a.seriesIndex!.compareTo(b.seriesIndex!));
      expect(series.meetingsTotal, 2);
      expect(series.totalPerMeeting, 240000);
      expect(series.weekday, DateTime.wednesday);
      expect(bookings.map((item) => item.seriesIndex), [1, 2]);
      expect(bookings.map((item) => item.proofBase64), [null, null]);
    });

    test(
      'does not partially create a series when one date conflicts',
      () async {
        await TestFixtures.seedBooking(
          db,
          data: TestFixtures.bookingData(
            date: '2026-11-25',
            startTime: '19:00',
            endTime: '20:00',
          ),
        );
        await expectLater(
          service.createSeries(
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
          ),
          throwsA(isA<SeriesConflictException>()),
        );
        expect((await db.collection('subscriptions').get()).docs, isEmpty);
        expect((await db.collection('bookings').get()).docs, hasLength(1));
      },
    );

    test('updates series and pending meetings in one batch', () async {
      await TestFixtures.seedSeries(db);
      await TestFixtures.seedBooking(
        db,
        id: 'pending-meeting',
        data: TestFixtures.bookingData(seriesId: 'series-1'),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'cancelled-meeting',
        data: TestFixtures.bookingData(
          seriesId: 'series-1',
          status: 'cancelled',
        ),
      );
      await service.setSeriesStatus('series-1', 'confirmed');

      expect(
        (await db.collection('subscriptions').doc('series-1').get())
            .data()?['status'],
        'confirmed',
      );
      expect(
        (await db.collection('bookings').doc('pending-meeting').get())
            .data()?['status'],
        'confirmed',
      );
      expect(
        (await db.collection('bookings').doc('cancelled-meeting').get())
            .data()?['status'],
        'cancelled',
      );
      await expectLater(
        service.setSeriesStatus('series-1', 'pending'),
        throwsArgumentError,
      );
    });

    test('cancels one meeting and records its date', () async {
      await TestFixtures.seedSeries(db);
      await TestFixtures.seedBooking(
        db,
        id: 'meeting',
        data: TestFixtures.bookingData(seriesId: 'series-1'),
      );
      await service.cancelSeriesMeeting(
        bookingId: 'meeting',
        seriesId: 'series-1',
        date: '2026-11-18',
      );
      expect(
        (await db.collection('bookings').doc('meeting').get())
            .data()?['status'],
        'cancelled',
      );
      expect(
        (await db.collection('subscriptions').doc('series-1').get())
            .data()?['cancelledMeetingDates'],
        ['2026-11-18'],
      );
    });

    test('cancels only remaining confirmed meetings', () async {
      final futureDate = fmtDate(DateTime.now().add(const Duration(days: 3)));
      final pastDate = fmtDate(
        DateTime.now().subtract(const Duration(days: 3)),
      );
      await TestFixtures.seedSeries(
        db,
        data: TestFixtures.seriesData(status: 'confirmed'),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'future',
        data: TestFixtures.bookingData(
          date: futureDate,
          status: 'confirmed',
          seriesId: 'series-1',
        ),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'past',
        data: TestFixtures.bookingData(
          date: pastDate,
          status: 'confirmed',
          seriesId: 'series-1',
        ),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'pending',
        data: TestFixtures.bookingData(
          date: futureDate,
          status: 'pending',
          seriesId: 'series-1',
        ),
      );

      expect(await service.cancelRemainingSeries('series-1'), 1);
      expect(
        (await db.collection('bookings').doc('future').get()).data()?['status'],
        'cancelled',
      );
      expect(
        (await db.collection('bookings').doc('past').get()).data()?['status'],
        'confirmed',
      );
      expect(
        (await db.collection('bookings').doc('pending').get())
            .data()?['status'],
        'pending',
      );
      expect(
        (await db.collection('subscriptions').doc('series-1').get())
            .data()?['status'],
        'cancelled',
      );
    });
  });
}
