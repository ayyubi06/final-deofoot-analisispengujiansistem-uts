import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/notifications_logic.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:deofoot/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_fixtures.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUpAll(TestFixtures.registerFallbackValues);

  setUp(() {
    db = TestFixtures.firestore();
    TestFixtures.setPreferences();
  });

  test(
    'permission request is safe when Android implementation is unavailable',
    () async {
      final plugin = TestFixtures.notificationPlugin();
      final android = TestFixtures.androidNotificationPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(null);

      await NotificationService.forTest(
        plugin: plugin,
        firestoreService: FirestoreService(db: db),
      ).mintaIzin();

      verifyNever(() => android.requestNotificationsPermission());
    },
  );

  test('schedules a future confirmed booking reminder', () async {
    final date = fmtDate(DateTime.now().add(const Duration(days: 2)));
    await TestFixtures.seedBooking(
      db,
      id: 'future-confirmed',
      data: TestFixtures.bookingData(date: date, status: 'confirmed'),
    );
    final plugin = TestFixtures.notificationPlugin();

    await NotificationService.forTest(
      plugin: plugin,
      firestoreService: FirestoreService(db: db),
    ).rekonsiliasiUntukUser('user-1');

    TestFixtures.verifyScheduled(plugin);
    TestFixtures.verifyNotShown(plugin);
  });

  test(
    'does not show an immediate reminder already recorded as shown',
    () async {
      final now = DateTime.now();
      final starts = now.add(const Duration(minutes: 30));
      final id = idNotifikasi('already-shown', JenisPengingat.main);
      TestFixtures.setPreferences({
        'notif_segera_sudah_tampil': ['$id'],
      });
      await TestFixtures.seedBooking(
        db,
        id: 'already-shown',
        data: TestFixtures.bookingData(
          date: fmtDate(starts),
          startTime:
              '${starts.hour.toString().padLeft(2, '0')}:'
              '${starts.minute.toString().padLeft(2, '0')}',
          status: 'confirmed',
          createdAt: now,
        ),
      );
      final plugin = TestFixtures.notificationPlugin();

      await NotificationService.forTest(
        plugin: plugin,
        firestoreService: FirestoreService(db: db),
      ).rekonsiliasiUntukUser('user-1');

      TestFixtures.verifyNotShown(plugin);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'notif_segera_sudah_tampil',
        ),
        ['$id'],
      );
    },
  );

  test(
    'schedules payment reminders only for the first meeting in a series',
    () async {
      final now = DateTime.now();
      final date = fmtDate(now.add(const Duration(days: 1)));
      await TestFixtures.seedBooking(
        db,
        id: 'meeting-first',
        data: TestFixtures.bookingData(
          date: date,
          seriesId: 'series-1',
          seriesIndex: 1,
          createdAt: now,
        ),
      );
      await TestFixtures.seedBooking(
        db,
        id: 'meeting-second',
        data: TestFixtures.bookingData(
          date: date,
          seriesId: 'series-1',
          seriesIndex: 2,
          createdAt: now,
        ),
      );
      final plugin = TestFixtures.notificationPlugin();

      await NotificationService.forTest(
        plugin: plugin,
        firestoreService: FirestoreService(db: db),
      ).rekonsiliasiUntukUser('user-1');

      TestFixtures.verifyScheduled(plugin);
    },
  );

  test(
    'omits confirmed series meetings outside the fourteen-day window',
    () async {
      final date = fmtDate(DateTime.now().add(const Duration(days: 16)));
      await TestFixtures.seedBooking(
        db,
        id: 'far-meeting',
        data: TestFixtures.bookingData(
          date: date,
          status: 'confirmed',
          seriesId: 'series-1',
          seriesIndex: 2,
        ),
      );
      final plugin = TestFixtures.notificationPlugin();

      await NotificationService.forTest(
        plugin: plugin,
        firestoreService: FirestoreService(db: db),
      ).rekonsiliasiUntukUser('user-1');

      TestFixtures.verifyNotScheduled(plugin);
      TestFixtures.verifyNotShown(plugin);
    },
  );

  test('does not plan reminders for another user’s booking', () async {
    await TestFixtures.seedBooking(
      db,
      data: TestFixtures.bookingData(userId: 'user-2'),
    );
    final plugin = TestFixtures.notificationPlugin();

    await NotificationService.forTest(
      plugin: plugin,
      firestoreService: FirestoreService(db: db),
    ).rekonsiliasiUntukUser('user-1');

    TestFixtures.verifyNotScheduled(plugin);
    TestFixtures.verifyNotShown(plugin);
  });
}
