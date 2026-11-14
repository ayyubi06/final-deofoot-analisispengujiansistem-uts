import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fase2_helpers.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreService service;

  setUp(() {
    fake = FakeFirebaseFirestore();
    service = FirestoreService(db: fake);
  });

  group('fields', () {
    test('watchFields mengembalikan lapangan yang di-seed', () async {
      await seedField(fake, id: 'l1', name: 'Lapangan 1');
      await seedField(fake, id: 'p1', name: 'Padel 1', price: 250000);
      final fields = await service.watchFields().first;
      expect(fields.map((f) => f.id), containsAll(['l1', 'p1']));
      expect(fields.firstWhere((f) => f.id == 'p1').pricePerHour, 250000);
    });

    test('createField + updateField + setFieldActive', () async {
      final field = Field(id: 't1', name: 'Tenis 1', pricePerHour: 150000);
      await service.createField(field);
      var doc = await fake.collection('fields').doc('t1').get();
      expect(doc.data()?['name'], 'Tenis 1');
      await service.updateField(
        Field(id: 't1', name: 'Tenis 1 Baru', pricePerHour: 175000),
      );
      doc = await fake.collection('fields').doc('t1').get();
      expect(doc.data()?['name'], 'Tenis 1 Baru');
      expect(doc.data()?['pricePerHour'], 175000);
      await service.setFieldActive('t1', false);
      doc = await fake.collection('fields').doc('t1').get();
      expect(doc.data()?['isActive'], false);
    });
  });

  group('config & users', () {
    test('getPaymentConfig dari dokumen config', () async {
      await seedPaymentConfig(fake);
      final cfg = await service.getPaymentConfig();
      expect(cfg['danaNumber'], '081234567890');
      expect(cfg['danaName'], 'Deofoot');
    });

    test('getPaymentConfig tanpa dokumen -> tanda -', () async {
      final cfg = await service.getPaymentConfig();
      expect(cfg['danaNumber'], '-');
      expect(cfg['danaName'], '-');
    });

    test('isAdmin true/false/tanpa dokumen', () async {
      await seedUser(fake, uid: 'admin1', isAdmin: true);
      await seedUser(fake, uid: 'u1', isAdmin: false);
      expect(await service.isAdmin('admin1'), true);
      expect(await service.isAdmin('u1'), false);
      expect(await service.isAdmin('tidak-ada'), false);
    });

    test(
      'ensureUserDoc membuat dokumen baru, tidak menimpa yang ada',
      () async {
        await service.ensureUserDoc('baru1', 'baru@test.com');
        var doc = await fake.collection('users').doc('baru1').get();
        expect(doc.exists, true);
        expect(doc.data()?['email'], 'baru@test.com');
        expect(doc.data()?['isAdmin'], false);

        await seedUser(fake, uid: 'lama1', isAdmin: true);
        await service.ensureUserDoc('lama1', 'lain@test.com');
        doc = await fake.collection('users').doc('lama1').get();
        expect(doc.data()?['isAdmin'], true);
        expect(doc.data()?['email'], 'u1@test.com');
      },
    );
  });

  group('watch bookings', () {
    test('watchBookings memfilter lapangan + tanggal', () async {
      await seedBooking(fake, id: 'b1', fieldId: 'l1', date: '2026-11-20');
      await seedBooking(
        fake,
        id: 'b2',
        fieldId: 'l1',
        date: '2026-11-20',
        startTime: '20:00',
        endTime: '21:00',
      );
      await seedBooking(fake, id: 'b3', fieldId: 'l1', date: '2026-11-21');
      await seedBooking(fake, id: 'b4', fieldId: 'p1', date: '2026-11-20');
      final list = await service.watchBookings('l1', '2026-11-20').first;
      expect(list.map((b) => b.id), containsAll(['b1', 'b2']));
      expect(list.length, 2);
    });

    test('watchBookingsByDate semua lapangan satu tanggal', () async {
      await seedBooking(fake, id: 'b1', fieldId: 'l1', date: '2026-11-20');
      await seedBooking(fake, id: 'b2', fieldId: 'p1', date: '2026-11-20');
      await seedBooking(fake, id: 'b3', fieldId: 'l1', date: '2026-11-21');
      final list = await service.watchBookingsByDate('2026-11-20').first;
      expect(list.length, 2);
    });

    test('watchMyBookings milik user, urut createdAt menurun', () async {
      final lama = DateTime.now().subtract(const Duration(hours: 2));
      final baru = DateTime.now();
      await seedBooking(fake, id: 'b-lama', userId: 'u1', createdAt: lama);
      await seedBooking(fake, id: 'b-baru', userId: 'u1', createdAt: baru);
      await seedBooking(fake, id: 'b-lain', userId: 'u2', createdAt: baru);
      final list = await service.watchMyBookings('u1').first;
      expect(list.map((b) => b.id).toList(), ['b-baru', 'b-lama']);
    });

    test('watchPending hanya pending, urut createdAt menaik', () async {
      final lama = DateTime.now().subtract(const Duration(hours: 2));
      final baru = DateTime.now();
      await seedBooking(fake, id: 'b-baru', status: 'pending', createdAt: baru);
      await seedBooking(fake, id: 'b-lama', status: 'pending', createdAt: lama);
      await seedBooking(fake, id: 'b-ok', status: 'confirmed', createdAt: lama);
      final list = await service.watchPending().first;
      expect(list.map((b) => b.id).toList(), ['b-lama', 'b-baru']);
    });

    test('watchBookingsInRange rentang inklusif', () async {
      await seedBooking(fake, id: 'b1', date: '2026-11-18');
      await seedBooking(fake, id: 'b2', date: '2026-11-20');
      await seedBooking(fake, id: 'b3', date: '2026-11-25');
      final list = await service
          .watchBookingsInRange('2026-11-19', '2026-11-21')
          .first;
      expect(list.map((b) => b.id).toList(), ['b2']);
    });

    test('watchBookingsToday hanya tanggal hari ini', () async {
      final hariIni = fmtDate(DateTime.now());
      final kemarin = fmtDate(DateTime.now().subtract(const Duration(days: 1)));
      await seedBooking(fake, id: 'b1', date: hariIni);
      await seedBooking(fake, id: 'b2', date: kemarin);
      final list = await service.watchBookingsToday().first;
      expect(list.map((b) => b.id).toList(), ['b1']);
    });
  });

  group('createBooking', () {
    test('sukses menulis booking pending dan mengembalikan id', () async {
      final id = await service.createBooking(
        userId: 'u1',
        userEmail: 'u1@test.com',
        fieldId: 'l1',
        fieldName: 'Lapangan 1',
        date: '2026-11-20',
        startHour: 19,
        endHour: 21,
        whatsapp: '08123456789',
        proofBase64: 'base64bukti',
        totalPrice: 240000,
        pricePerHour: 120000,
      );
      expect(id, isNotEmpty);
      final doc = await fake.collection('bookings').doc(id).get();
      expect(doc.data()?['status'], 'pending');
      expect(doc.data()?['startTime'], '19:00');
      expect(doc.data()?['endTime'], '21:00');
      expect(doc.data()?['totalPrice'], 240000);
      expect(doc.data()?['pricePerHour'], 120000);
    });

    test('bentrok melempar BookingConflictException', () async {
      await seedBooking(
        fake,
        id: 'b1',
        fieldId: 'l1',
        date: '2026-11-20',
        startTime: '19:00',
        endTime: '20:00',
      );
      try {
        await service.createBooking(
          userId: 'u2',
          userEmail: 'u2@test.com',
          fieldId: 'l1',
          fieldName: 'Lapangan 1',
          date: '2026-11-20',
          startHour: 19,
          endHour: 21,
          whatsapp: '0812',
          proofBase64: 'x',
          totalPrice: 240000,
          pricePerHour: 120000,
        );
        fail('seharusnya melempar BookingConflictException');
      } on BookingConflictException catch (e) {
        expect(e.toString(), contains('Slot sudah dibooking'));
      }
      final snap = await fake.collection('bookings').get();
      expect(snap.docs.length, 1);
    });

    test('slot bersebelahan (tanpa tumpang tindih) lolos', () async {
      await seedBooking(
        fake,
        id: 'b1',
        fieldId: 'l1',
        date: '2026-11-20',
        startTime: '19:00',
        endTime: '20:00',
      );
      final id = await service.createBooking(
        userId: 'u2',
        userEmail: 'u2@test.com',
        fieldId: 'l1',
        fieldName: 'Lapangan 1',
        date: '2026-11-20',
        startHour: 20,
        endHour: 21,
        whatsapp: '0812',
        proofBase64: 'x',
        totalPrice: 120000,
        pricePerHour: 120000,
      );
      expect(id, isNotEmpty);
    });
  });

  group('expireStalePendings & status', () {
    test('expireStalePendings hanya meng-expire pending lama', () async {
      final now = DateTime.now();
      await seedBooking(
        fake,
        id: 'b-lama',
        status: 'pending',
        createdAt: now.subtract(const Duration(minutes: 40)),
      );
      await seedBooking(
        fake,
        id: 'b-baru',
        status: 'pending',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );
      await seedBooking(
        fake,
        id: 'b-ok',
        status: 'confirmed',
        createdAt: now.subtract(const Duration(minutes: 40)),
      );
      await seedBooking(
        fake,
        id: 'b-tanpa-created',
        status: 'pending',
        omitCreatedAt: true,
      );
      final n = await service.expireStalePendings();
      expect(n, 1);
      final lama = await fake.collection('bookings').doc('b-lama').get();
      expect(lama.data()?['status'], 'expired');
      final baru = await fake.collection('bookings').doc('b-baru').get();
      expect(baru.data()?['status'], 'pending');
      final tanpa = await fake
          .collection('bookings')
          .doc('b-tanpa-created')
          .get();
      expect(tanpa.data()?['status'], 'pending');
    });

    test('cancelBooking mengubah status', () async {
      await seedBooking(fake, id: 'b1', status: 'confirmed');
      await service.cancelBooking('b1');
      final doc = await fake.collection('bookings').doc('b1').get();
      expect(doc.data()?['status'], 'cancelled');
    });

    test('setBookingStatus confirmed/rejected, status lain ditolak', () async {
      await seedBooking(fake, id: 'b1', status: 'pending');
      await service.setBookingStatus('b1', 'confirmed');
      var doc = await fake.collection('bookings').doc('b1').get();
      expect(doc.data()?['status'], 'confirmed');
      await service.setBookingStatus('b1', 'rejected');
      doc = await fake.collection('bookings').doc('b1').get();
      expect(doc.data()?['status'], 'rejected');
      await expectLater(
        () => service.setBookingStatus('b1', 'ngawur'),
        throwsArgumentError,
      );
    });
  });

  group('seri langganan', () {
    test(
      'watchMySeries + watchPendingSeries + watchBookingsBySeries',
      () async {
        final lama = DateTime.now().subtract(const Duration(hours: 2));
        final baru = DateTime.now();
        await seedSeries(
          fake,
          id: 's-lama',
          userId: 'u1',
          status: 'pending',
          createdAt: lama,
        );
        await seedSeries(
          fake,
          id: 's-baru',
          userId: 'u1',
          status: 'confirmed',
          createdAt: baru,
        );
        await seedSeries(
          fake,
          id: 's-lain',
          userId: 'u2',
          status: 'pending',
          createdAt: baru,
        );
        await seedBooking(fake, id: 'b1', seriesId: 's-lama', seriesIndex: 1);
        await seedBooking(fake, id: 'b2', seriesId: 's-lama', seriesIndex: 2);
        await seedBooking(fake, id: 'b3', seriesId: 's-baru', seriesIndex: 1);

        final milikku = await service.watchMySeries('u1').first;
        expect(milikku.map((s) => s.id).toList(), ['s-baru', 's-lama']);
        final pending = await service.watchPendingSeries().first;
        expect(pending.map((s) => s.id).toList(), ['s-lama', 's-lain']);
        final pertemuan = await service.watchBookingsBySeries('s-lama').first;
        expect(pertemuan.length, 2);
      },
    );

    test('createSeries sukses: seri + 2 pertemuan tertulis atomik', () async {
      final id = await service.createSeries(
        userId: 'u1',
        userEmail: 'u1@test.com',
        fieldId: 'l1',
        fieldName: 'Lapangan 1',
        meetingDates: ['2026-11-21', '2026-11-28'],
        startHour: 19,
        endHour: 20,
        whatsapp: '0812',
        proofBase64: 'bukti',
        pricePerHour: 120000,
      );
      expect(id, isNotEmpty);
      final seri = await fake.collection('subscriptions').doc(id).get();
      expect(seri.data()?['status'], 'pending');
      expect(seri.data()?['meetingsTotal'], 2);
      expect(seri.data()?['totalPerMeeting'], 120000);
      final pertemuan = await fake
          .collection('bookings')
          .where('seriesId', isEqualTo: id)
          .get();
      expect(pertemuan.docs.length, 2);
      final idx =
          pertemuan.docs.map((d) => d.data()['seriesIndex'] as int).toList()
            ..sort();
      expect(idx, [1, 2]);
      expect(pertemuan.docs.first.data()['proofBase64'], isNull);
    });

    test('createSeries bentrok: tidak ada yang tertulis', () async {
      await seedBooking(
        fake,
        id: 'b1',
        fieldId: 'l1',
        date: '2026-11-28',
        startTime: '19:00',
        endTime: '20:00',
      );
      try {
        await service.createSeries(
          userId: 'u1',
          userEmail: 'u1@test.com',
          fieldId: 'l1',
          fieldName: 'Lapangan 1',
          meetingDates: ['2026-11-21', '2026-11-28'],
          startHour: 19,
          endHour: 20,
          whatsapp: '0812',
          proofBase64: 'bukti',
          pricePerHour: 120000,
        );
        fail('seharusnya melempar SeriesConflictException');
      } on SeriesConflictException catch (e) {
        expect(e.tanggalKonflik, ['2026-11-28']);
        expect(e.message, contains('2026-11-28'));
        expect(e.toString(), contains('2026-11-28'));
      }
      final seri = await fake.collection('subscriptions').get();
      expect(seri.docs, isEmpty);
      final bookings = await fake.collection('bookings').get();
      expect(bookings.docs.length, 1);
    });

    test('setSeriesStatus atomik: seri + pertemuan pending berubah', () async {
      await seedSeries(fake, id: 's1', status: 'pending');
      await seedBooking(
        fake,
        id: 'b1',
        seriesId: 's1',
        seriesIndex: 1,
        status: 'pending',
      );
      await seedBooking(
        fake,
        id: 'b2',
        seriesId: 's1',
        seriesIndex: 2,
        status: 'pending',
      );
      await seedBooking(
        fake,
        id: 'b3',
        seriesId: 's1',
        seriesIndex: 3,
        status: 'cancelled',
      );
      await service.setSeriesStatus('s1', 'confirmed');
      final seri = await fake.collection('subscriptions').doc('s1').get();
      expect(seri.data()?['status'], 'confirmed');
      final b1 = await fake.collection('bookings').doc('b1').get();
      expect(b1.data()?['status'], 'confirmed');
      final b3 = await fake.collection('bookings').doc('b3').get();
      expect(b3.data()?['status'], 'cancelled');
      await expectLater(
        () => service.setSeriesStatus('s1', 'ngawur'),
        throwsArgumentError,
      );
    });

    test(
      'cancelSeriesMeeting membatalkan satu pertemuan + mencatat tanggal',
      () async {
        await seedSeries(
          fake,
          id: 's1',
          status: 'confirmed',
          meetingDates: ['2026-11-21', '2026-11-28'],
        );
        await seedBooking(
          fake,
          id: 'b1',
          seriesId: 's1',
          seriesIndex: 1,
          date: '2026-11-21',
          status: 'confirmed',
        );
        await seedBooking(
          fake,
          id: 'b2',
          seriesId: 's1',
          seriesIndex: 2,
          date: '2026-11-28',
          status: 'confirmed',
        );
        await service.cancelSeriesMeeting(
          bookingId: 'b1',
          seriesId: 's1',
          date: '2026-11-21',
        );
        final b1 = await fake.collection('bookings').doc('b1').get();
        expect(b1.data()?['status'], 'cancelled');
        final b2 = await fake.collection('bookings').doc('b2').get();
        expect(b2.data()?['status'], 'confirmed');
        final seri = await fake.collection('subscriptions').doc('s1').get();
        expect(seri.data()?['cancelledMeetingDates'], ['2026-11-21']);
      },
    );

    test('cancelRemainingSeries hanya membatalkan pertemuan mendatang yang confirmed', () async {
      final besok = fmtDate(DateTime.now().add(const Duration(days: 1)));
      final kemarin = fmtDate(DateTime.now().subtract(const Duration(days: 1)));
      await seedSeries(fake, id: 's1', status: 'confirmed');
      await seedBooking(
        fake,
        id: 'b-depan',
        seriesId: 's1',
        seriesIndex: 1,
        date: besok,
        startTime: '19:00',
        endTime: '20:00',
        status: 'confirmed',
      );
      await seedBooking(
        fake,
        id: 'b-lewat',
        seriesId: 's1',
        seriesIndex: 2,
        date: kemarin,
        startTime: '19:00',
        endTime: '20:00',
        status: 'confirmed',
      );
      await seedBooking(
        fake,
        id: 'b-pending',
        seriesId: 's1',
        seriesIndex: 3,
        date: besok,
        startTime: '20:00',
        endTime: '21:00',
        status: 'pending',
      );
      final n = await service.cancelRemainingSeries('s1');
      expect(n, 1);
      final depan = await fake.collection('bookings').doc('b-depan').get();
      expect(depan.data()?['status'], 'cancelled');
      final lewat = await fake.collection('bookings').doc('b-lewat').get();
      expect(lewat.data()?['status'], 'confirmed');
      final pending = await fake.collection('bookings').doc('b-pending').get();
      expect(pending.data()?['status'], 'pending');
      final seri = await fake.collection('subscriptions').doc('s1').get();
      expect(seri.data()?['status'], 'cancelled');
    });
  });
}
