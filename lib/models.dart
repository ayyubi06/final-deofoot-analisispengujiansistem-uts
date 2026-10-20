import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Model lapangan (futsal, padel, tenis, mini soccer).
class Field {
  final String id;
  final String name;
  final int pricePerHour;
  final String category;
  final Color color;

  /// Fase C: false = lapangan disembunyikan dari user & tidak bisa
  /// dibooking (pengganti hapus permanen). Dokumen lama tanpa field ini
  /// dianggap aktif.
  final bool isActive;

  /// Fase C: jam operasional dari `scheduleGrid` dokumen
  /// ({openHour, closeHour}). Dokumen lama tanpa scheduleGrid → 08–22.
  final int openHour;
  final int closeHour;

  Field({
    required this.id,
    required this.name,
    required this.pricePerHour,
    this.category = 'Futsal',
    this.color = DeofootTheme.primary,
    this.isActive = true,
    this.openHour = 8,
    this.closeHour = 22,
  });

  factory Field.fromDoc(DocumentSnapshot doc) {
    return Field.fromMap(
        doc.id, doc.data() as Map<String, dynamic>? ?? {});
  }

  /// Konstruktor dari map mentah (dipakai juga untuk unit test).
  factory Field.fromMap(String id, Map<String, dynamic> d) {
    final grid = d['scheduleGrid'] as Map<String, dynamic>?;
    return Field(
      id: id,
      name: d['name'] as String? ?? id,
      pricePerHour: (d['pricePerHour'] as num?)?.toInt() ?? 120000,
      category: d['category'] as String? ?? 'Futsal',
      color: _parseColor(d['color']),
      isActive: d['isActive'] as bool? ?? true,
      openHour: (grid?['openHour'] as num?)?.toInt() ?? 8,
      closeHour: (grid?['closeHour'] as num?)?.toInt() ?? 22,
    );
  }

  /// Map untuk tulis Firestore (admin kelola lapangan, Fase C).
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pricePerHour': pricePerHour,
      'category': category,
      'color': color.toARGB32(),
      'isActive': isActive,
      'scheduleGrid': {'openHour': openHour, 'closeHour': closeHour},
    };
  }

  /// Path foto lapangan: `assets/images/fields/<id>.jpg` (id lowercase).
  /// (l1.jpg, p1.jpg, t1.jpg, m1.jpg, ...).
  String get photoAsset => 'assets/images/fields/${id.toLowerCase()}.jpg';
}

/// Parse warna dari Firestore: int ARGB atau String "#RRGGBB".
/// Fallback ke navy bila format tidak dikenali.
Color _parseColor(Object? v) {
  if (v is int) return Color(v);
  if (v is String) {
    var s = v.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    final n = int.tryParse(s, radix: 16);
    if (n != null) return Color(n);
  }
  return DeofootTheme.primary;
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
  final String status; // pending | confirmed | rejected | cancelled | expired
  final String? proofBase64;
  final int totalPrice;

  /// Snapshot harga per jam lapangan SAAT booking dibuat (Fase C):
  /// riwayat & laporan tidak berubah walau harga lapangan diubah admin.
  /// Dokumen lama tanpa field ini → 0.
  final int pricePerHour;

  /// Id seri langganan (Fase E) bila booking ini pertemuan dari sebuah
  /// seri; null untuk booking biasa.
  final String? seriesId;
  final String whatsapp;
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
    this.pricePerHour = 0,
    this.seriesId,
    this.whatsapp = '',
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
      pricePerHour: (d['pricePerHour'] as num?)?.toInt() ?? 0,
      seriesId: d['seriesId'] as String?,
      whatsapp: d['whatsapp'] as String? ?? '',
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
    if (status == 'cancelled' ||
        status == 'rejected' ||
        status == 'expired') {
      return false;
    }
    return !startDateTime.isBefore(DateTime.now());
  }
}

/// Model seri langganan slot rutin (Fase E) — dokumen `subscriptions`.
/// Setiap pertemuan seri adalah dokumen booking biasa yang menunjuk
/// seri ini lewat `seriesId`. Bukti bayar hanya ada di dokumen seri.
class SubscriptionSeries {
  final String id;
  final String userId;
  final String userEmail;
  final String fieldId;
  final String fieldName;
  final int weekday; // 1=Senin .. 7=Minggu
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final int pricePerHour; // snapshot saat seri dibuat
  final int totalPerMeeting;
  final int meetingsTotal;
  final String startDate; // yyyy-MM-dd pertemuan pertama
  final String endDate; // yyyy-MM-dd pertemuan terakhir
  final List<String> meetingDates;
  final String whatsapp;
  final String? proofBase64;
  final String status; // pending | confirmed | rejected | cancelled
  final List<String> cancelledMeetingDates;
  final DateTime createdAt;

  SubscriptionSeries({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.fieldId,
    required this.fieldName,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.pricePerHour,
    required this.totalPerMeeting,
    required this.meetingsTotal,
    required this.startDate,
    required this.endDate,
    required this.meetingDates,
    this.whatsapp = '',
    this.proofBase64,
    required this.status,
    this.cancelledMeetingDates = const [],
    required this.createdAt,
  });

  factory SubscriptionSeries.fromDoc(DocumentSnapshot doc) {
    return SubscriptionSeries.fromMap(
        doc.id, doc.data() as Map<String, dynamic>? ?? {});
  }

  /// Konstruktor dari map mentah (dipakai juga untuk unit test).
  factory SubscriptionSeries.fromMap(String id, Map<String, dynamic> d) {
    List<String> strList(Object? v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    return SubscriptionSeries(
      id: id,
      userId: d['userId'] as String? ?? '',
      userEmail: d['userEmail'] as String? ?? '',
      fieldId: d['fieldId'] as String? ?? '',
      fieldName: d['fieldName'] as String? ?? '',
      weekday: (d['weekday'] as num?)?.toInt() ?? 1,
      startTime: d['startTime'] as String? ?? '',
      endTime: d['endTime'] as String? ?? '',
      pricePerHour: (d['pricePerHour'] as num?)?.toInt() ?? 0,
      totalPerMeeting: (d['totalPerMeeting'] as num?)?.toInt() ?? 0,
      meetingsTotal: (d['meetingsTotal'] as num?)?.toInt() ?? 0,
      startDate: d['startDate'] as String? ?? '',
      endDate: d['endDate'] as String? ?? '',
      meetingDates: strList(d['meetingDates']),
      whatsapp: d['whatsapp'] as String? ?? '',
      proofBase64: d['proofBase64'] as String?,
      status: d['status'] as String? ?? 'pending',
      cancelledMeetingDates: strList(d['cancelledMeetingDates']),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Total harga seluruh seri.
  int get totalHarga => totalPerMeeting * meetingsTotal;
}
