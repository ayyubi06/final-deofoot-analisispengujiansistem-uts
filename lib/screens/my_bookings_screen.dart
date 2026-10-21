import 'package:flutter/material.dart';

import '../booking_logic.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/pitch_components.dart';
import 'user_series_screen.dart';

/// Layar 6 — Booking Saya: tab Akan datang + Riwayat.
/// (Fase G §3.6: kartu Pitch, chip status bertukar crossfade+blur,
/// kartu seri membuka rincian seri pengguna. Fungsi & redaksi
/// tidak berubah dari v0.4.1.)
class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser!.uid;
    final fs = FirestoreService();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Booking Saya'),
          bottom: const TabBar(
            indicatorColor: DeofootTheme.volt,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [Tab(text: 'Akan datang'), Tab(text: 'Riwayat')],
          ),
        ),
        body: Column(
          children: [
            // Catatan kejujuran cakupan notifikasi (spek A5, rework T15).
            Container(
              width: double.infinity,
              color: DeofootTheme.pitch700.withValues(alpha: 0.06),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notifications_outlined,
                      size: 16, color: DeofootTheme.pitch700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pengingat di aplikasi ini hanya pengingat jadwal '
                      '(batas bayar & mulai main) yang tersimpan di HP '
                      'kamu. Perubahan status verifikasi dari admin '
                      'tidak memunculkan notifikasi — itu membutuhkan '
                      'notifikasi push server (FCM).',
                      style: TextStyle(
                          fontSize: 12, color: DeofootTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Booking>>(
                stream: fs.watchMyBookings(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        PitchSkeletonCard(),
                        SizedBox(height: 16),
                        PitchSkeletonCard(),
                      ],
                    );
                  }
                  final all = snap.data ?? [];
                  final upcoming = all.where((b) => b.isUpcoming).toList();
                  final history = all.where((b) => !b.isUpcoming).toList();
                  return TabBarView(
                    children: [
                      _list(context, upcoming, showCancel: true),
                      _list(context, history, showCancel: false),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
      BuildContext context, List<Booking> items,
      {required bool showCancel}) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Belum ada booking.',
            style: TextStyle(color: DeofootTheme.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _BookingCard(
        booking: items[i],
        showCancel: showCancel,
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final bool showCancel;
  const _BookingCard({required this.booking, required this.showCancel});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final canCancel = showCancel && b.canCancel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PitchCard(
        // Kartu seri: ketuk -> rincian seri pengguna (§3.6).
        onTap: b.seriesId == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserSeriesScreen(
                      fieldName: b.fieldName,
                      meetingsStream: FirestoreService()
                          .watchBookingsBySeries(b.seriesId!),
                    ),
                  ),
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    b.fieldName,
                    style: DeofootTheme.bodyStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: DeofootTheme.pitch900,
                    ),
                  ),
                ),
                if (b.seriesId != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          DeofootTheme.volt.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.repeat,
                            size: 12, color: DeofootTheme.pitch700),
                        const SizedBox(width: 4),
                        Text(
                          'Langganan',
                          style: DeofootTheme.captionStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: DeofootTheme.pitch700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Chip status bertukar dengan crossfade+blur (§3.6)
                // memakai bungkus yang sama dengan obat kedip grid.
                StatusSwapFade(
                  swapKey: b.status,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DeofootTheme.statusColor(b.status)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      DeofootTheme.statusLabel(b.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DeofootTheme.statusColor(b.status),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${b.date} • ${b.startTime}–${b.endTime}',
                style: const TextStyle(color: DeofootTheme.textMuted)),
            Text(
              fmtRupiah(b.totalPrice),
              style: DeofootTheme.tabular(
                DeofootTheme.bodyStyle
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (showCancel) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: canCancel
                      ? () => _confirmCancel(context)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DeofootTheme.danger,
                    side: BorderSide(
                      color: canCancel
                          ? DeofootTheme.danger
                          : DeofootTheme.booked,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          DeofootTheme.radiusButton),
                    ),
                  ),
                  child: const Text('Batalkan'),
                ),
              ),
              if (!b.canCancel &&
                  (b.status == 'pending' || b.status == 'confirmed'))
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Tidak bisa dibatalkan (≤ 2 jam sebelum mulai).',
                    style: TextStyle(
                        fontSize: 12, color: DeofootTheme.textMuted),
                  ),
                ),
              // Sisa seri hanya untuk pertemuan yang sudah Disetujui
              // (spek E7, rework T12) — seri pending dibatalkan per
              // pertemuan lewat tombol Batalkan biasa.
              if (b.seriesId != null && b.status == 'confirmed') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancelSeries(context),
                    icon: const Icon(Icons.repeat, size: 18),
                    label: const Text('Batalkan sisa seri'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeofootTheme.danger,
                      side: const BorderSide(color: DeofootTheme.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            DeofootTheme.radiusButton),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan booking?'),
        content: Text(
            'Booking ${booking.fieldName} pada ${booking.date} jam ${booking.startTime} akan dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: DeofootTheme.danger),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        // Pertemuan seri: batalkan lewat jalur seri agar tanggalnya
        // tercatat di dokumen seri (Fase E). Booking biasa: jalur lama.
        if (booking.seriesId != null) {
          await FirestoreService().cancelSeriesMeeting(
            bookingId: booking.id,
            seriesId: booking.seriesId!,
            date: booking.date,
          );
        } else {
          await FirestoreService().cancelBooking(booking.id);
        }
        // Pengingat booking ini dibatalkan oleh rekonsiliasi (Fase A).
        final uid = AuthService().currentUser?.uid;
        if (uid != null) NotificationService().rekonsiliasiUntukUser(uid);
        messenger.showSnackBar(
          const SnackBar(content: Text('Booking dibatalkan.')),
        );
      } catch (e) {
        debugPrint('MyBookingsScreen._confirmCancel gagal: $e');
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Gagal membatalkan. Coba lagi.'),
              backgroundColor: DeofootTheme.danger),
        );
      }
    }
  }

  /// Batalkan SISA seri (Fase E): semua pertemuan yang belum dimainkan.
  /// Pertemuan yang sudah lewat / sudah dibatalkan tidak diubah.
  Future<void> _confirmCancelSeries(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan sisa seri?'),
        content: Text(
            'Semua pertemuan seri ${booking.fieldName} yang belum dimainkan akan dibatalkan. Pertemuan yang sudah lewat tidak berubah.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: DeofootTheme.danger),
            child: const Text('Ya, batalkan sisa seri'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final n =
            await FirestoreService().cancelRemainingSeries(booking.seriesId!);
        final uid = AuthService().currentUser?.uid;
        if (uid != null) NotificationService().rekonsiliasiUntukUser(uid);
        messenger.showSnackBar(
          SnackBar(content: Text('Sisa seri dibatalkan ($n pertemuan).')),
        );
      } catch (e) {
        debugPrint('MyBookingsScreen._confirmCancelSeries gagal: $e');
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Gagal membatalkan seri. Coba lagi.'),
              backgroundColor: DeofootTheme.danger),
        );
      }
    }
  }
}
