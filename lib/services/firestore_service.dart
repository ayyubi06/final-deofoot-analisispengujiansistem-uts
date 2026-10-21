import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import '../models.dart';
import '../booking_logic.dart';
import '../recurring_logic.dart';

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

  // --- Admin: kelola lapangan (Fase C) ---
  // CATATAN: rules produksi saat ini membuat `fields` read-only untuk
  // semua orang. Tulis di bawah ini baru berfungsi setelah usulan rules
  // v0.4 (lihat firestore-rules-v04-usulan.rules) dipublish — publish
  // menunggu review keamanan inka + persetujuan tuan muda.
  Future<void> createField(Field f) async {
    await _db.collection('fields').doc(f.id).set(f.toMap());
  }

  Future<void> updateField(Field f) async {
    await _db.collection('fields').doc(f.id).update(f.toMap());
  }

  /// Nonaktifkan / aktifkan kembali lapangan (pengganti hapus permanen).
  Future<void> setFieldActive(String fieldId, bool active) async {
    await _db
        .collection('fields')
        .doc(fieldId)
        .update({'isActive': active});
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

  /// Semua booking pada satu tanggal, semua lapangan (untuk
  /// Pencarian Slot lintas lapangan, Fase D).
  Stream<List<Booking>> watchBookingsByDate(String date) {
    return _db
        .collection('bookings')
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

  /// Semua booking dalam rentang tanggal main inklusif (yyyy-MM-dd),
  /// untuk laporan admin (Fase B). Penyaringan status dilakukan
  /// hitungLaporan — hanya confirmed yang terhitung.
  Stream<List<Booking>> watchBookingsInRange(String mulai, String akhir) {
    return _db
        .collection('bookings')
        .where('date', isGreaterThanOrEqualTo: mulai)
        .where('date', isLessThanOrEqualTo: akhir)
        .snapshots()
        .map((s) => s.docs.map(Booking.fromDoc).toList());
  }

  /// Semua booking HARI INI (untuk dashboard mini admin).
  Stream<List<Booking>> watchBookingsToday() {
    return _db
        .collection('bookings')
        .where('date', isEqualTo: fmtDate(DateTime.now()))
        .snapshots()
        .map((s) => s.docs.map(Booking.fromDoc).toList());
  }

  /// Buat booking dengan cek ulang anti double-booking TEPAT SEBELUM tulis,
  /// di dalam transaction (re-check + tulis atomik).
  /// Lempar [BookingConflictException] jika slot sudah terisi.
  Future<String> createBooking({
    required String userId,
    required String userEmail,
    required String fieldId,
    required String fieldName,
    required String date,
    required int startHour,
    required int endHour,
    required String whatsapp,
    required String proofBase64,
    required int totalPrice,
    required int pricePerHour,
  }) async {
    final startMin = startHour * 60;
    final endMin = endHour * 60;
    final startTime =
        '${startHour.toString().padLeft(2, '0')}:00';
    final endTime =
        '${endHour.toString().padLeft(2, '0')}:00';

    final col = _db.collection('bookings');
    final q = col
        .where('fieldId', isEqualTo: fieldId)
        .where('date', isEqualTo: date);
    return _db.runTransaction((tx) async {
      // Re-check tepat sebelum tulis: baca booking terbaru lapangan+tanggal.
      // (API Transaction hanya mendukung get per-dokumen, jadi query
      // dibaca via get() biasa tepat sebelum tx.set.)
      final snap = await q.get();
      final existing = snap.docs.map(Booking.fromDoc).toList();
      if (hasConflict(existing, fieldId, date, startMin, endMin)) {
        throw BookingConflictException(
            'Slot sudah dibooking orang lain. Silakan pilih jam lain.');
      }
      final ref = col.doc();
      tx.set(ref, {
        'userId': userId,
        'userEmail': userEmail,
        'fieldId': fieldId,
        'fieldName': fieldName,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'status': 'pending',
        'whatsapp': whatsapp,
        'proofBase64': proofBase64,
        'totalPrice': totalPrice,
        // Snapshot harga saat booking dibuat (Fase C).
        'pricePerHour': pricePerHour,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    });
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
    if (status != 'confirmed' && status != 'rejected') {
      throw ArgumentError('Status booking tidak valid: $status');
    }
    await _db.collection('bookings').doc(bookingId).update({
      'status': status,
    });
  }

  // --- Langganan rutin / seri (Fase E) ---

  /// Seri milik user (untuk kebutuhan tampilan/verifikasi lanjutan).
  Stream<List<SubscriptionSeries>> watchMySeries(String uid) {
    return _db
        .collection('subscriptions')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(SubscriptionSeries.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Seri pending (untuk admin verifikasi per seri).
  Stream<List<SubscriptionSeries>> watchPendingSeries() {
    return _db
        .collection('subscriptions')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
      final list = s.docs.map(SubscriptionSeries.fromDoc).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  /// Semua booking pertemuan milik satu seri — untuk rincian seri
  /// di layar Verifikasi (micro-fix v0.4.1, Addendum 4).
  Stream<List<Booking>> watchBookingsBySeries(String seriesId) {
    return _db
        .collection('bookings')
        .where('seriesId', isEqualTo: seriesId)
        .snapshots()
        .map((s) => s.docs.map(Booking.fromDoc).toList());
  }

  /// Buat seri langganan + semua booking pertemuannya dalam SATU
  /// transaction (all-or-nothing): seluruh tanggal dicek ulang tepat
  /// sebelum tulis; satu saja bentrok → [SeriesConflictException] dan
  /// tidak ada yang tertulis.
  Future<String> createSeries({
    required String userId,
    required String userEmail,
    required String fieldId,
    required String fieldName,
    required List<String> meetingDates,
    required int startHour,
    required int endHour,
    required String whatsapp,
    required String proofBase64,
    required int pricePerHour,
  }) async {
    final startMin = startHour * 60;
    final endMin = endHour * 60;
    final startTime = '${startHour.toString().padLeft(2, '0')}:00';
    final endTime = '${endHour.toString().padLeft(2, '0')}:00';
    final totalPerMeeting =
        bookingTotal(endHour - startHour, pricePerHour);
    final colBookings = _db.collection('bookings');
    final colSeries = _db.collection('subscriptions');
    return _db.runTransaction((tx) async {
      // Re-check SEMUA tanggal tepat sebelum tulis.
      final perTanggal = <String, List<Booking>>{};
      for (final t in meetingDates) {
        final snap = await colBookings
            .where('fieldId', isEqualTo: fieldId)
            .where('date', isEqualTo: t)
            .get();
        perTanggal[t] = snap.docs.map(Booking.fromDoc).toList();
      }
      final konflik = tanggalKonflikSeri(
        tanggalSeri: meetingDates,
        bookingsPerTanggal: perTanggal,
        fieldId: fieldId,
        startMin: startMin,
        endMin: endMin,
      );
      if (konflik.isNotEmpty) {
        throw SeriesConflictException(konflik);
      }
      final sref = colSeries.doc();
      tx.set(sref, {
        'userId': userId,
        'userEmail': userEmail,
        'fieldId': fieldId,
        'fieldName': fieldName,
        'weekday': DateTime.parse(meetingDates.first).weekday,
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
        'status': 'pending',
        'cancelledMeetingDates': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (var i = 0; i < meetingDates.length; i++) {
        final bref = colBookings.doc();
        tx.set(bref, {
          'userId': userId,
          'userEmail': userEmail,
          'fieldId': fieldId,
          'fieldName': fieldName,
          'date': meetingDates[i],
          'startTime': startTime,
          'endTime': endTime,
          'status': 'pending',
          'whatsapp': whatsapp,
          'proofBase64': null,
          'totalPrice': totalPerMeeting,
          'pricePerHour': pricePerHour,
          'seriesId': sref.id,
          'seriesIndex': i + 1, // nomor urut pertemuan 1..n (E5)
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return sref.id;
    });
  }

  /// Admin: setujui (→confirmed) / tolak (→rejected) SELURUH seri
  /// secara ATOMIK (rework T19, spek E6): dokumen seri + semua booking
  /// pertemuannya yang masih pending ditulis dalam SATU batch —
  /// tidak ada keadaan setengah jadi bila gagal di tengah.
  /// Yang sudah dibatalkan per pertemuan tidak diubah.
  Future<void> setSeriesStatus(String seriesId, String status) async {
    if (status != 'confirmed' && status != 'rejected') {
      throw ArgumentError('Status seri tidak valid: $status');
    }
    final snap = await _db
        .collection('bookings')
        .where('seriesId', isEqualTo: seriesId)
        .where('status', isEqualTo: 'pending')
        .get();
    final batch = _db.batch();
    batch.update(_db.collection('subscriptions').doc(seriesId), {
      'status': status,
    });
    for (final d in snap.docs) {
      batch.update(d.reference, {'status': status});
    }
    await batch.commit();
  }

  /// Batalkan SATU pertemuan seri (oleh user): booking → cancelled dan
  /// tanggalnya dicatat di `cancelledMeetingDates` dokumen seri.
  /// Pertemuan lain tidak terpengaruh.
  Future<void> cancelSeriesMeeting({
    required String bookingId,
    required String seriesId,
    required String date,
  }) async {
    final batch = _db.batch();
    batch.update(_db.collection('bookings').doc(bookingId), {
      'status': 'cancelled',
    });
    batch.update(_db.collection('subscriptions').doc(seriesId), {
      'cancelledMeetingDates': FieldValue.arrayUnion([date]),
    });
    await batch.commit();
  }

  /// Batalkan SISA seri (spek E7): hanya pertemuan mendatang yang
  /// masih Disetujui (confirmed) → cancelled; status seri → cancelled.
  /// Mengembalikan jumlah pertemuan yang dibatalkan.
  Future<int> cancelRemainingSeries(String seriesId) async {
    final snap = await _db
        .collection('bookings')
        .where('seriesId', isEqualTo: seriesId)
        .get();
    final bookings = snap.docs.map(Booking.fromDoc).toList();
    final sisa = sisaPertemuan(bookings, DateTime.now());
    final batch = _db.batch();
    for (final b in sisa) {
      batch.update(_db.collection('bookings').doc(b.id), {
        'status': 'cancelled',
      });
    }
    batch.update(_db.collection('subscriptions').doc(seriesId), {
      'status': 'cancelled',
    });
    await batch.commit();
    return sisa.length;
  }
}

class BookingConflictException implements Exception {
  final String message;
  BookingConflictException(this.message);
  @override
  String toString() => message;
}

/// Seri langganan gagal dibuat karena tanggal-tanggal ini bentrok.
/// Tidak ada dokumen apa pun yang tertulis (all-or-nothing).
class SeriesConflictException implements Exception {
  final List<String> tanggalKonflik;
  SeriesConflictException(this.tanggalKonflik);
  String get message =>
      'Slot bentrok pada ${tanggalKonflik.length} tanggal: ${tanggalKonflik.join(', ')}';
  @override
  String toString() => message;
}
