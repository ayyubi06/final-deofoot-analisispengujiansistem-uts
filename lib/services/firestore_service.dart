import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import '../models.dart';
import '../booking_logic.dart';

/// Akses Firestore sesuai rules:
/// - fields & config: read-only
/// - users/{uid}: read/create milik sendiri
/// - bookings: create milik sendiri; read milik sendiri atau admin
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Fields (read-only) ---
  Stream<List<Field>> watchFields() {
    return _db.collection('fields').snapshots().map(
        (s) => s.docs.map(Field.fromDoc).toList());
  }

  // --- Config pembayaran (read-only, DANA dari Firestore bukan hardcode) ---
  Future<Map<String, String>> getPaymentConfig() async {
    final doc = await _db.collection('config').doc('payment').get();
    final d = doc.data() ?? {};
    return {
      'danaNumber': d['danaNumber'] as String? ?? '-',
      'danaName': d['danaName'] as String? ?? '-',
    };
  }

  // --- Users ---
  Future<bool> isAdmin(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['isAdmin'] as bool?) ?? false;
  }

  Future<void> ensureUserDoc(String uid, String email) async {
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'email': email,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // --- Bookings ---
  /// Booking untuk 1 lapangan + tanggal (untuk grid slot & cek bentrok).
  Stream<List<Booking>> watchBookings(String fieldId, String date) {
    return _db
        .collection('bookings')
        .where('fieldId', isEqualTo: fieldId)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((s) => s.docs.map(Booking.fromDoc).toList());
  }

  /// Booking milik user (untuk Booking Saya).
  Stream<List<Booking>> watchMyBookings(String uid) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(Booking.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Booking pending (untuk admin verifikasi).
  Stream<List<Booking>> watchPending() {
    return _db
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
      final list = s.docs.map(Booking.fromDoc).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  /// Buat booking dengan cek ulang anti double-booking TEPAT SEBELUM tulis.
  /// Lempar [BookingConflictException] jika slot sudah terisi.
  Future<String> createBooking({
    required String userId,
    required String userEmail,
    required String fieldId,
    required String fieldName,
    required String date,
    required int startHour,
    required String proofBase64,
    required int totalPrice,
  }) async {
    final startMin = startHour * 60;
    final endMin = startMin + 60;
    final startTime =
        '${startHour.toString().padLeft(2, '0')}:00';
    final endTime =
        '${(startHour + 1).toString().padLeft(2, '0')}:00';

    // Cek ulang: baca booking terbaru untuk lapangan+tanggal ini.
    final snap = await _db
        .collection('bookings')
        .where('fieldId', isEqualTo: fieldId)
        .where('date', isEqualTo: date)
        .get();
    final existing =
        snap.docs.map(Booking.fromDoc).toList();
    if (hasConflict(existing, fieldId, date, startMin, endMin)) {
      throw BookingConflictException(
          'Slot sudah dibooking orang lain. Silakan pilih jam lain.');
    }

    final ref = await _db.collection('bookings').add({
      'userId': userId,
      'userEmail': userEmail,
      'fieldId': fieldId,
      'fieldName': fieldName,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'status': 'pending',
      'proofBase64': proofBase64,
      'totalPrice': totalPrice,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Expire booking pending yang createdAt-nya > 30 menit.
  /// Hanya update field status (sesuai rules). Return jumlah yang di-expire.
  /// Dipanggil saat app start & saat buka jadwal (fire and forget).
  Future<int> expireStalePendings() async {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
    final snap = await _db
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .get();
    var n = 0;
    for (final doc in snap.docs) {
      final created = (doc.data()['createdAt'] as Timestamp?)?.toDate();
      if (created != null && created.isBefore(cutoff)) {
        await doc.reference.update({'status': 'expired'});
        n++;
      }
    }
    return n;
  }

  /// Batalkan booking (user hanya boleh ke 'cancelled').
  Future<void> cancelBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
    });
  }

  /// Admin: terima (→confirmed) / tolak (→rejected).
  Future<void> setBookingStatus(String bookingId, String status) async {
    assert(status == 'confirmed' || status == 'rejected');
    await _db.collection('bookings').doc(bookingId).update({
      'status': status,
    });
  }
}

class BookingConflictException implements Exception {
  final String message;
  BookingConflictException(this.message);
  @override
  String toString() => message;
}
