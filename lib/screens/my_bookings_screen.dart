import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Layar 6 — Booking Saya: tab Akan datang + Riwayat.
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
            tabs: [Tab(text: 'Akan datang'), Tab(text: 'Riwayat')],
          ),
        ),
        body: StreamBuilder<List<Booking>>(
          stream: fs.watchMyBookings(uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lapangan ${b.fieldName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DeofootTheme.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DeofootTheme.statusColor(b.status)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
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
              ],
            ),
            const SizedBox(height: 8),
            Text('${b.date} • ${b.startTime}–${b.endTime}',
                style:
                    const TextStyle(color: DeofootTheme.textMuted)),
            Text(fmtRupiah(b.totalPrice),
                style: const TextStyle(fontWeight: FontWeight.w600)),
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
                      borderRadius: BorderRadius.circular(8),
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
            'Booking Lapangan ${booking.fieldName} pada ${booking.date} jam ${booking.startTime} akan dibatalkan.'),
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
        await FirestoreService().cancelBooking(booking.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Booking dibatalkan.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Gagal membatalkan: $e'),
              backgroundColor: DeofootTheme.danger),
        );
      }
    }
  }
}
