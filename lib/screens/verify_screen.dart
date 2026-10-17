import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../services/firestore_service.dart';

/// Layar 8 — Verifikasi (admin): list booking pending + Terima/Tolak.
class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Pembayaran')),
      body: StreamBuilder<List<Booking>>(
        stream: fs.watchPending(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('Tidak ada booking menunggu verifikasi.',
                  style:
                      TextStyle(color: DeofootTheme.textMuted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _PendingCard(booking: items[i]),
          );
        },
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Booking booking;
  const _PendingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    Widget thumb;
    if (b.proofBase64 != null && b.proofBase64!.isNotEmpty) {
      try {
        thumb = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(b.proofBase64!),
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        thumb = _noProof();
      }
    } else {
      thumb = _noProof();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            thumb,
            const SizedBox(height: 12),
            Text(b.userEmail,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
                'Lapangan ${b.fieldName} • ${b.date} • ${b.startTime}–${b.endTime}',
                style:
                    const TextStyle(color: DeofootTheme.textMuted)),
            Text('Total: ${fmtRupiah(b.totalPrice)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _confirm(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DeofootTheme.available,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Terima'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _confirm(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeofootTheme.danger,
                      side: const BorderSide(
                          color: DeofootTheme.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _noProof() => Container(
        height: 80,
        decoration: BoxDecoration(
          color: DeofootTheme.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Bukti tidak tersedia',
              style: TextStyle(color: DeofootTheme.textMuted)),
        ),
      );

  Future<void> _confirm(BuildContext context, bool terima) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(terima ? 'Terima booking?' : 'Tolak booking?'),
        content: Text(
          terima
              ? 'Booking ${booking.userEmail} (${booking.fieldName}, ${booking.date} ${booking.startTime}) akan DISETUJUI.'
              : 'Booking ${booking.userEmail} (${booking.fieldName}, ${booking.date} ${booking.startTime}) akan DITOLAK dan slot kembali bebas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: terima
                  ? DeofootTheme.available
                  : DeofootTheme.danger,
            ),
            child: Text(terima ? 'Ya, terima' : 'Ya, tolak'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await FirestoreService().setBookingStatus(
          booking.id,
          terima ? 'confirmed' : 'rejected',
        );
        messenger.showSnackBar(
          SnackBar(
              content: Text(terima
                  ? 'Booking disetujui.'
                  : 'Booking ditolak, slot kembali bebas.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Gagal: $e'),
              backgroundColor: DeofootTheme.danger),
        );
      }
    }
  }
}
