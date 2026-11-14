import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/notifications_logic.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:deofoot/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers/fase2_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: '123',
        appId: '123',
        messagingSenderId: '123',
        projectId: '123',
      ),
    );
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime.utc(2000));
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
  });

  late FakeFirebaseFirestore fake;
  late MockPlugin plugin;
  late NotificationService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    plugin = MockPlugin();
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(() => plugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    when(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    service = NotificationService.forTest(
      plugin: plugin,
      firestoreService: FirestoreService(db: fake),
    );
  });

  tearDown(() {
    NotificationService.onTap = null;
  });

  test('singleton: NotificationService() selalu instance yang sama', () {
    expect(NotificationService(), same(NotificationService()));
  });

  test('init memanggil initialize sekali walau dipanggil dua kali', () async {
    await service.init();
    await service.init();
    verify(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).called(1);
  });

  test('ketukan notifikasi memanggil onTap dengan payload bookingId', () async {
    await service.init();
    final captured =
        verify(
              () => plugin.initialize(
                settings: any(named: 'settings'),
                onDidReceiveNotificationResponse: captureAny(
                  named: 'onDidReceiveNotificationResponse',
                ),
              ),
            ).captured.single
            as void Function(NotificationResponse);
    String? tapped;
    NotificationService.onTap = (id) => tapped = id;
    final resp = MockNotificationResponse();
    when(() => resp.payload).thenReturn('b1');
    captured(resp);
    expect(tapped, 'b1');
  });

  test('mintaIzin meminta izin Android bila tersedia', () async {
    final android = MockAndroidPlugin();
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(android);
    when(() => android.requestNotificationsPermission())
        .thenAnswer((_) async => true);
    await service.mintaIzin();
    verify(() => android.requestNotificationsPermission()).called(1);
  });

  test('mintaIzin selesai diam bila plugin Android tidak ada', () async {
    await service.mintaIzin();
  });

  group('rekonsiliasiUntukUser', () {
    test('pengingat masa depan dijadwalkan', () async {
      final besok = fmtDate(DateTime.now().add(const Duration(days: 1)));
      await seedBooking(
        fake,
        id: 'b-pending',
        userId: 'u1',
        status: 'pending',
        date: besok,
        startTime: '19:00',
        endTime: '20:00',
        createdAt: DateTime.now(),
      );
      await seedBooking(
        fake,
        id: 'b-confirmed',
        userId: 'u1',
        status: 'confirmed',
        date: besok,
        startTime: '20:00',
        endTime: '21:00',
      );
      await service.rekonsiliasiUntukUser('u1');
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
      ).called(2);
      verifyNever(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      );
      verifyNever(() => plugin.cancel(id: any(named: 'id')));
    });

    test(
      'pengingat main yang sudah waktunya ditampilkan segera + dicatat',
      () async {
        final mulai = DateTime.now().add(const Duration(minutes: 30));
        final jamMulai = DateTime(
          mulai.year,
          mulai.month,
          mulai.day,
          mulai.hour + 1,
        );
        final jamAkhir = (jamMulai.hour + 1) % 24;
        await seedBooking(
          fake,
          id: 'b1',
          userId: 'u1',
          status: 'confirmed',
          date: fmtDate(jamMulai),
          startTime: '${jamMulai.hour.toString().padLeft(2, '0')}:00',
          endTime: '${jamAkhir.toString().padLeft(2, '0')}:00',
        );
        await service.rekonsiliasiUntukUser('u1');
        final id = idNotifikasi('b1', JenisPengingat.main);
        verify(
          () => plugin.show(
            id: id,
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: 'b1',
          ),
        ).called(1);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('notif_segera_sudah_tampil'),
          contains('$id'),
        );
      },
    );

    test('pengingat yatim dibatalkan', () async {
      when(() => plugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [const PendingNotificationRequest(999999, 't', 'b', null)],
      );
      await service.rekonsiliasiUntukUser('u1');
      verify(() => plugin.cancel(id: 999999)).called(1);
    });

    test('yang sudah tampil tidak ditampilkan ulang', () async {
      final mulai = DateTime.now().add(const Duration(minutes: 30));
      final jamMulai = DateTime(
        mulai.year,
        mulai.month,
        mulai.day,
        mulai.hour + 1,
      );
      final jamAkhir = (jamMulai.hour + 1) % 24;
      await seedBooking(
        fake,
        id: 'b1',
        userId: 'u1',
        status: 'confirmed',
        date: fmtDate(jamMulai),
        startTime: '${jamMulai.hour.toString().padLeft(2, '0')}:00',
        endTime: '${jamAkhir.toString().padLeft(2, '0')}:00',
      );
      final id = idNotifikasi('b1', JenisPengingat.main);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('notif_segera_sudah_tampil', ['$id']);
      await service.rekonsiliasiUntukUser('u1');
      verifyNever(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test('kegagalan plugin tidak melempar ke pemanggil', () async {
      when(() => plugin.pendingNotificationRequests())
          .thenThrow(Exception('boom'));
      await service.rekonsiliasiUntukUser('u1');
    });

    test('tanpa booking: tidak ada panggilan plugin', () async {
      await service.rekonsiliasiUntukUser('u1');
      verifyNever(() => plugin.cancel(id: any(named: 'id')));
      verifyNever(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      );
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
    });
  });
}
