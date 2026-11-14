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
    NotificationService.onTap = null;
  });

  test('initializes once and requests notification permission', () async {
    final plugin = TestFixtures.notificationPlugin();
    final android = TestFixtures.androidNotificationPlugin();
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(android);
    final service = NotificationService.forTest(
      plugin: plugin,
      firestoreService: FirestoreService(db: db),
    );

    await service.mintaIzin();
    await service.mintaIzin();

    verify(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).called(1);
    verify(() => android.requestNotificationsPermission()).called(2);
  });

  test(
    'routes a notification tap payload through the static callback',
    () async {
      final plugin = TestFixtures.notificationPlugin();
      final service = NotificationService.forTest(
        plugin: plugin,
        firestoreService: FirestoreService(db: db),
      );
      String? tappedId;
      NotificationService.onTap = (id) => tappedId = id;
      await service.init();

      final callback =
          verify(
                () => plugin.initialize(
                  settings: any(named: 'settings'),
                  onDidReceiveNotificationResponse: captureAny(
                    named: 'onDidReceiveNotificationResponse',
                  ),
                ),
              ).captured.single
              as DidReceiveNotificationResponseCallback;
      callback(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'booking-1',
        ),
      );

      expect(tappedId, 'booking-1');
    },
  );

  test('schedules a future payment reminder and persists shown ids', () async {
    final now = DateTime.now();
    await TestFixtures.seedBooking(
      db,
      id: 'pending-booking',
      data: TestFixtures.bookingData(
        date: fmtDate(now.add(const Duration(days: 1))),
        createdAt: now,
      ),
    );
    final plugin = TestFixtures.notificationPlugin();
    final service = NotificationService.forTest(
      plugin: plugin,
      firestoreService: FirestoreService(db: db),
    );

    await service.rekonsiliasiUntukUser('user-1');

    verify(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
      ),
    ).called(1);
    verifyNever(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    );
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'notif_segera_sudah_tampil',
      ),
      isEmpty,
    );
  });

  test('shows an immediate play reminder only once and records it', () async {
    final now = DateTime.now();
    final starts = now.add(const Duration(minutes: 30));
    await TestFixtures.seedBooking(
      db,
      id: 'confirmed-booking',
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
    final service = NotificationService.forTest(
      plugin: plugin,
      firestoreService: FirestoreService(db: db),
    );

    await service.rekonsiliasiUntukUser('user-1');

    verify(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).called(1);
    final shown = (await SharedPreferences.getInstance()).getStringList(
      'notif_segera_sudah_tampil',
    );
    expect(shown, isNotEmpty);
    expect(
      shown,
      contains('${idNotifikasi('confirmed-booking', JenisPengingat.main)}'),
    );
  });

  test(
    'avoids duplicate scheduling and cancels notifications outside plan',
    () async {
      final now = DateTime.now();
      await TestFixtures.seedBooking(
        db,
        id: 'pending-booking',
        data: TestFixtures.bookingData(
          date: fmtDate(now.add(const Duration(days: 1))),
          createdAt: now,
        ),
      );
      final plannedId = idNotifikasi('pending-booking', JenisPengingat.bayar);
      final plugin = TestFixtures.notificationPlugin(
        pending: [
          PendingNotificationRequest(plannedId, null, null, null),
          PendingNotificationRequest(999, null, null, null),
        ],
      );
      final service = NotificationService.forTest(
        plugin: plugin,
        firestoreService: FirestoreService(db: db),
      );

      await service.rekonsiliasiUntukUser('user-1');

      verifyNever(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      );
      verify(() => plugin.cancel(id: 999)).called(1);
    },
  );

  test(
    'removes stale shown ids when their booking no longer has a plan',
    () async {
      TestFixtures.setPreferences({
        'notif_segera_sudah_tampil': ['123', 'not-an-int'],
      });
      final plugin = TestFixtures.notificationPlugin();
      final service = NotificationService.forTest(
        plugin: plugin,
        firestoreService: FirestoreService(db: db),
      );

      await service.rekonsiliasiUntukUser('user-1');

      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'notif_segera_sudah_tampil',
        ),
        isEmpty,
      );
    },
  );

  test('contains plugin errors without propagating them to caller', () async {
    final plugin = TestFixtures.notificationPlugin();
    when(() => plugin.pendingNotificationRequests())
        .thenAnswer((_) async => throw StateError('plugin unavailable'));
    final service = NotificationService.forTest(
      plugin: plugin,
      firestoreService: FirestoreService(db: db),
    );

    await expectLater(service.rekonsiliasiUntukUser('user-1'), completes);
  });
}
