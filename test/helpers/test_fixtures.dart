import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class MockNotificationPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockAndroidNotificationPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class MockAuth extends Mock implements FirebaseAuth {}

class _FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class _FakeNotificationDetails extends Fake implements NotificationDetails {}

class _FakeTZDateTime extends Fake implements tz.TZDateTime {}

class TestFixtures {
  static void registerFallbackValues() {
    registerFallbackValue(_FakeInitializationSettings());
    registerFallbackValue(_FakeNotificationDetails());
    registerFallbackValue(_FakeTZDateTime());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
  }

  static FakeFirebaseFirestore firestore() => FakeFirebaseFirestore();

  static MockFirebaseAuth auth({
    String uid = 'user-1',
    String email = 'user@example.test',
  }) => MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: uid, email: email),
  );

  static MockAuth authThatFails({
    required String code,
    String? message,
    required bool register,
  }) {
    final auth = MockAuth();
    final exception = FirebaseAuthException(code: code, message: message);
    if (register) {
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => throw exception);
    } else {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => throw exception);
    }
    return auth;
  }

  static Map<String, dynamic> fieldData({
    String name = 'Lapangan 1',
    int pricePerHour = 120000,
    String category = 'Futsal',
    int color = 0xff102a43,
    bool isActive = true,
  }) => {
    'name': name,
    'pricePerHour': pricePerHour,
    'category': category,
    'color': color,
    'isActive': isActive,
  };

  static Map<String, dynamic> bookingData({
    String userId = 'user-1',
    String userEmail = 'user@example.test',
    String fieldId = 'field-1',
    String fieldName = 'Lapangan 1',
    String date = '2026-11-18',
    String startTime = '19:00',
    String endTime = '20:00',
    String status = 'pending',
    String? proofBase64 = 'proof',
    int totalPrice = 120000,
    int pricePerHour = 120000,
    String? seriesId,
    int? seriesIndex,
    String whatsapp = '081234567890',
    DateTime? createdAt,
  }) => {
    'userId': userId,
    'userEmail': userEmail,
    'fieldId': fieldId,
    'fieldName': fieldName,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'status': status,
    'proofBase64': proofBase64,
    'totalPrice': totalPrice,
    'pricePerHour': pricePerHour,
    if (seriesId != null) 'seriesId': seriesId,
    if (seriesIndex != null) 'seriesIndex': seriesIndex,
    'whatsapp': whatsapp,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 11, 14, 8)),
  };

  static Map<String, dynamic> seriesData({
    String userId = 'user-1',
    String userEmail = 'user@example.test',
    String fieldId = 'field-1',
    String fieldName = 'Lapangan 1',
    int weekday = 3,
    String startTime = '19:00',
    String endTime = '20:00',
    int pricePerHour = 120000,
    int totalPerMeeting = 120000,
    List<String> meetingDates = const ['2026-11-18', '2026-11-25'],
    String whatsapp = '081234567890',
    String? proofBase64 = 'proof',
    String status = 'pending',
    List<String> cancelledMeetingDates = const [],
    DateTime? createdAt,
  }) => {
    'userId': userId,
    'userEmail': userEmail,
    'fieldId': fieldId,
    'fieldName': fieldName,
    'weekday': weekday,
    'startTime': startTime,
    'endTime': endTime,
    'pricePerHour': pricePerHour,
    'totalPerMeeting': totalPerMeeting,
    'meetingsTotal': meetingDates.length,
    'startDate': meetingDates.first,
    'endDate': meetingDates.last,
    'meetingDates': meetingDates,
    'whatsapp': whatsapp,
    'proofBase64': proofBase64,
    'status': status,
    'cancelledMeetingDates': cancelledMeetingDates,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 11, 14, 8)),
  };

  static Future<void> seedField(
    FakeFirebaseFirestore db, {
    String id = 'field-1',
    Map<String, dynamic>? data,
  }) => db.collection('fields').doc(id).set(data ?? fieldData());

  static Future<void> seedBooking(
    FakeFirebaseFirestore db, {
    String id = 'booking-1',
    Map<String, dynamic>? data,
  }) => db.collection('bookings').doc(id).set(data ?? bookingData());

  static Future<void> seedSeries(
    FakeFirebaseFirestore db, {
    String id = 'series-1',
    Map<String, dynamic>? data,
  }) => db.collection('subscriptions').doc(id).set(data ?? seriesData());

  static Future<void> seedPaymentConfig(
    FakeFirebaseFirestore db, {
    String danaNumber = '081234567890',
    String danaName = 'Deofoot',
  }) => db.collection('config').doc('payment').set({
    'danaNumber': danaNumber,
    'danaName': danaName,
  });

  static MockNotificationPlugin notificationPlugin({
    List<PendingNotificationRequest> pending = const [],
  }) {
    final plugin = MockNotificationPlugin();
    final android = androidNotificationPlugin();
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(android);
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(() => plugin.pendingNotificationRequests())
        .thenAnswer((_) async => pending);
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
    return plugin;
  }

  static MockAndroidNotificationPlugin androidNotificationPlugin() {
    final plugin = MockAndroidNotificationPlugin();
    when(() => plugin.requestNotificationsPermission())
        .thenAnswer((_) async => true);
    return plugin;
  }

  static void setPreferences([Map<String, Object> initialValues = const {}]) {
    SharedPreferences.setMockInitialValues(initialValues);
  }
}
