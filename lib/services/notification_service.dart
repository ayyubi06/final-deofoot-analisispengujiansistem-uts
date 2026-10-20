import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../notifications_logic.dart';
import 'firestore_service.dart';

/// Service notifikasi lokal (Fase A v0.4) — membungkus
/// flutter_local_notifications. Semua keputusan (apa yang dijadwalkan /
/// ditampilkan / dibatalkan) dihitung oleh logika murni di
/// notifications_logic.dart; service ini hanya mengeksekusinya.
///
/// Penjadwalan memakai mode INEXACT (AndroidScheduleMode
/// .inexactAllowWhileIdle): aplikasi tidak meminta izin alarm eksak.
/// Waktu dijadwalkan sebagai instan absolut (TZDateTime dari DateTime),
/// jadi tidak bergantung pada nama zona waktu perangkat.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  /// Dipanggil saat notifikasi diketuk; payload = bookingId.
  /// Diisi oleh MainNav untuk membuka tab Booking Saya.
  static void Function(String? bookingId)? onTap;

  static const _keyShown = 'notif_segera_sudah_tampil';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'pengingat_booking',
      'Pengingat Booking',
      channelDescription: 'Pengingat pembayaran dan waktu main Deofoot',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Inisialisasi plugin (aman dipanggil berulang).
  Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (resp) {
        onTap?.call(resp.payload);
      },
    );
    _inited = true;
  }

  /// Minta izin notifikasi (Android 13+). Penolakan tidak menghalangi
  /// aplikasi — penjadwalan tetap dicoba; sistem yang menahan tampilnya.
  Future<void> mintaIzin() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Rekonsiliasi pengingat untuk user yang sedang login: ambil booking
  /// milik user, hitung rencana, lalu jadwalkan / tampilkan segera /
  /// batalkan sesuai hasil rekonsiliasi. Fire-and-forget dari UI;
  /// kegagalan dicatat, tidak pernah melempar ke pemanggil.
  Future<void> rekonsiliasiUntukUser(String uid) async {
    try {
      await init();
      final bookings =
          await FirestoreService().watchMyBookings(uid).first;
      final pending = await _plugin.pendingNotificationRequests();
      final prefs = await SharedPreferences.getInstance();
      final shown = (prefs.getStringList(_keyShown) ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

      final rencana =
          rencanaNotifikasi(bookings: bookings, now: DateTime.now());
      final hasil = rekonsiliasiNotifikasi(
        rencana: rencana,
        idTerjadwal: pending.map((p) => p.id).toSet(),
        idSudahTampil: shown,
      );

      for (final id in hasil.batalkan) {
        await _plugin.cancel(id: id);
      }
      for (final r in hasil.jadwalkan) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.judul,
          body: r.isi,
          scheduledDate: tz.TZDateTime.from(r.waktu, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: r.bookingId,
        );
      }
      for (final r in hasil.tampilkanSegera) {
        await _plugin.show(
          id: r.id,
          title: r.judul,
          body: r.isi,
          notificationDetails: _details,
          payload: r.bookingId,
        );
        shown.add(r.id);
      }
      // Rapikan catatan "sudah tampil": buang id yang bookingnya sudah
      // tidak menghasilkan rencana apa pun (sudah lewat/selesai).
      final idRencana = rencana.map((r) => r.id).toSet();
      shown.removeWhere((id) => !idRencana.contains(id));
      await prefs.setStringList(
          _keyShown, shown.map((e) => '$e').toList());
    } catch (e) {
      debugPrint('NotificationService.rekonsiliasiUntukUser gagal: $e');
    }
  }
}
