import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';

// Mocktail mocks — didefinisikan SEKALI di sini, dipakai semua berkas test
// Fase 2. Jangan mendefinisikan ulang di berkas test (duplikasi).
// (Nama MockAuth — bukan MockFirebaseAuth — supaya tidak bentrok dengan
// MockFirebaseAuth dari package firebase_auth_mocks.)
class MockAuth extends Mock implements FirebaseAuth {}

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class MockNotificationResponse extends Mock
    implements NotificationResponse {}

/// Pemetaan kode error Firebase Auth -> pesan Indonesia (cerminan
/// AuthService._pesan). Dipakai test auth untuk signIn dan register.
const pesanAuthExpected = <String, String>{
  'invalid-email': 'Format email tidak valid.',
  'user-not-found': 'Akun tidak ditemukan. Silakan daftar dulu.',
  'wrong-password': 'Email atau password salah.',
  'invalid-credential': 'Email atau password salah.',
  'email-already-in-use': 'Email sudah terdaftar. Silakan masuk.',
  'weak-password': 'Password terlalu lemah (minimal 6 karakter).',
  'network-request-failed': 'Tidak ada koneksi internet.',
  'too-many-requests': 'Terlalu banyak percobaan. Coba lagi nanti.',
};

Future<void> seedField(
  FakeFirebaseFirestore db, {
  String id = 'l1',
  String name = 'Lapangan 1',
  int price = 120000,
  bool isActive = true,
}) async {
  await db.collection('fields').doc(id).set({
    'name': name,
    'pricePerHour': price,
    'category': 'Futsal',
    'color': 0xFF1B2A4A,
    'isActive': isActive,
  });
}

Future<void> seedBooking(
  FakeFirebaseFirestore db, {
  String id = 'b1',
  String userId = 'u1',
  String fieldId = 'l1',
  String date = '2026-11-20',
  String startTime = '19:00',
  String endTime = '20:00',
  String status = 'pending',
  DateTime? createdAt,
  bool omitCreatedAt = false,
  String? seriesId,
  int? seriesIndex,
}) async {
  final data = <String, dynamic>{
    'userId': userId,
    'userEmail': 'u1@test.com',
    'fieldId': fieldId,
    'fieldName': 'Lapangan 1',
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'status': status,
    'whatsapp': '08123456789',
    'proofBase64': null,
    'totalPrice': 120000,
    'pricePerHour': 120000,
    'seriesId': seriesId,
    'seriesIndex': seriesIndex,
  };
  if (!omitCreatedAt) {
    data['createdAt'] = Timestamp.fromDate(createdAt ?? DateTime.now());
  }
  await db.collection('bookings').doc(id).set(data);
}

Future<void> seedSeries(
  FakeFirebaseFirestore db, {
  String id = 's1',
  String userId = 'u1',
  String status = 'pending',
  List<String> meetingDates = const ['2026-11-21', '2026-11-28'],
  List<String> cancelledMeetingDates = const [],
  DateTime? createdAt,
}) async {
  await db.collection('subscriptions').doc(id).set({
    'userId': userId,
    'userEmail': 'u1@test.com',
    'fieldId': 'l1',
    'fieldName': 'Lapangan 1',
    'weekday': 6,
    'startTime': '19:00',
    'endTime': '20:00',
    'pricePerHour': 120000,
    'totalPerMeeting': 120000,
    'meetingsTotal': meetingDates.length,
    'startDate': meetingDates.first,
    'endDate': meetingDates.last,
    'meetingDates': meetingDates,
    'whatsapp': '08123456789',
    'proofBase64': null,
    'status': status,
    'cancelledMeetingDates': cancelledMeetingDates,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
  });
}

Future<void> seedUser(
  FakeFirebaseFirestore db, {
  String uid = 'u1',
  bool isAdmin = false,
}) async {
  await db.collection('users').doc(uid).set({
    'email': 'u1@test.com',
    'isAdmin': isAdmin,
  });
}

Future<void> seedPaymentConfig(
  FakeFirebaseFirestore db, {
  String danaNumber = '081234567890',
  String danaName = 'Deofoot',
}) async {
  await db.collection('config').doc('payment').set({
    'danaNumber': danaNumber,
    'danaName': danaName,
  });
}
