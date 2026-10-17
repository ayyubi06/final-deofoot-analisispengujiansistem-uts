import 'package:cloud_firestore/cloud_firestore.dart';

/// Model lapangan futsal.
class Field {
  final String id;
  final String name;
  final int pricePerHour;

  Field({required this.id, required this.name, required this.pricePerHour});

  factory Field.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Field(
      id: doc.id,
      name: d['name'] as String? ?? doc.id,
      pricePerHour: (d['pricePerHour'] as num?)?.toInt() ?? 120000,
    );
  }
}

/// Model booking.
class Booking {
  final String id;
  final String userId;
  final String userEmail;
  final String fieldId;
  final String fieldName;
  final String date; // yyyy-MM-dd
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String status; // pending | confirmed | rejected | cancelled
  final String? proofBase64;
  final int totalPrice;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.fieldId,
    required this.fieldName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.proofBase64,
    required this.totalPrice,
    required this.createdAt,
  });

  factory Booking.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Booking(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      userEmail: d['userEmail'] as String? ?? '',
      fieldId: d['fieldId'] as String? ?? '',
      fieldName: d['fieldName'] as String? ?? '',
      date: d['date'] as String? ?? '',
      startTime: d['startTime'] as String? ?? '',
      endTime: d['endTime'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      proofBase64: d['proofBase64'] as String?,
      totalPrice: (d['totalPrice'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  int get startMinutes => _toMinutes(startTime);
  int get endMinutes => _toMinutes(endTime);

  static int _toMinutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  /// DateTime mulai booking (untuk aturan batal 2 jam).
  DateTime get startDateTime {
    final dp = date.split('-').map(int.parse).toList();
    final tp = startTime.split(':').map(int.parse).toList();
    return DateTime(dp[0], dp[1], dp[2], tp[0], tp[1]);
  }

  /// true jika booking masih bisa dibatalkan (> 2 jam sebelum mulai).
  bool get canCancel {
    if (status != 'pending' && status != 'confirmed') return false;
    return startDateTime.difference(DateTime.now()).inMinutes > 120;
  }

  /// true jika booking masuk tab "Akan datang".
  bool get isUpcoming {
    if (status == 'cancelled' || status == 'rejected') return false;
    return !startDateTime.isBefore(DateTime.now());
  }
}
