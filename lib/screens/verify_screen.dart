import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../report_logic.dart' show namaHari;
import '../services/firestore_service.dart';

/// Layar 8 — Verifikasi (admin): list booking pending + Terima/Tolak,
/// dan seri langganan pending + Terima/Tolak per seri (Fase E).
class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Pembayaran')),
      body: Column(
        children: [
          const _Dashboard(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _SectionTitle('Booking menunggu'),
                _PendingBookings(),
                SizedBox(height: 8),
                _SectionTitle('Langganan menunggu'),
                _PendingSeries(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: DeofootTheme.primary,
        ),
      ),
    );
  }
}

class _PendingBookings extends StatelessWidget {
  const _PendingBookings();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: FirestoreService().watchPending(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Tidak ada booking menunggu verifikasi.',
                style: TextStyle(color: DeofootTheme.textMuted)),
          );
        }
        return Column(
          children: [for (final b in items) _PendingCard(booking: b)],
        );
      },
    );
  }
}

class _PendingSeries extends StatelessWidget {
  const _PendingSeries();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SubscriptionSeries>>(
      stream: FirestoreService().watchPendingSeries(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Text('Tidak ada langganan menunggu verifikasi.',
              style: TextStyle(color: DeofootTheme.textMuted));
        }
        return Column(
          children: [for (final s in items) _SeriesCard(series: s)],
        );
      },
    );
  }
}

/// Kartu seri langganan pending: Terima/Tolak berlaku untuk SELURUH
/// seri; booking pertemuan yang masih pending mengikuti (Fase E).
class _SeriesCard extends StatelessWidget {
  final SubscriptionSeries series;
  const _SeriesCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final s = series;
    Widget thumb;
    if (s.proofBase64 != null && s.proofBase64!.isNotEmpty) {
      try {
        thumb = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(s.proofBase64!),
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
    final hari = s.meetingDates.isNotEmpty
        ? namaHari(DateTime.parse(s.meetingDates.first))
        : '-';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.repeat,
                    size: 18, color: DeofootTheme.accent),
                const SizedBox(width: 6),
                const Text('Langganan rutin',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${s.meetingsTotal} pertemuan',
                    style: const TextStyle(color: DeofootTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            thumb,
            const SizedBox(height: 12),
            Text(s.userEmail,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('WA: ${s.whatsapp.isEmpty ? '-' : s.whatsapp}',
                style: const TextStyle(
                    fontSize: 13, color: DeofootTheme.textMuted)),
            const SizedBox(height: 4),
            Text(
              '${s.fieldName} • setiap $hari ${s.startTime}–${s.endTime}',
              style: const TextStyle(color: DeofootTheme.textMuted),
            ),
            Text(
              '${s.startDate} s/d ${s.endDate} • Total: ${fmtRupiah(s.totalHarga)}',
              style: const TextStyle(color: DeofootTheme.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirm(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DeofootTheme.available,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Terima seri'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirm(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeofootTheme.danger,
                      side: const BorderSide(color: DeofootTheme.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Tolak seri'),
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
        title: Text(terima ? 'Terima seri langganan?' : 'Tolak seri langganan?'),
        content: Text(
          terima
              ? 'Seluruh seri ${series.userEmail} (${series.fieldName}, ${series.meetingsTotal} pertemuan) akan DISETUJUI; semua pertemuannya ikut aktif.'
              : 'Seluruh seri ${series.userEmail} (${series.fieldName}, ${series.meetingsTotal} pertemuan) akan DITOLAK dan semua slotnya kembali bebas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  terima ? DeofootTheme.available : DeofootTheme.danger,
            ),
            child: Text(terima ? 'Ya, terima' : 'Ya, tolak'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await FirestoreService().setSeriesStatus(
          series.id,
          terima ? 'confirmed' : 'rejected',
        );
        messenger.showSnackBar(
          SnackBar(
              content: Text(terima
                  ? 'Seri disetujui, semua pertemuan aktif.'
                  : 'Seri ditolak, semua slot kembali bebas.')),
        );
      } catch (e) {
        debugPrint('VerifyScreen._SeriesCard._confirm gagal: $e');
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Gagal memproses. Coba lagi.'),
              backgroundColor: DeofootTheme.danger),
        );
      }
    }
  }
}

/// Dashboard mini admin: 3 angka hari ini, real-time dari Firestore.
class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: FirestoreService().watchBookingsToday(),
      builder: (context, snap) {
        final items = snap.data ?? [];
        final aktif = items
            .where((b) => b.status == 'pending' || b.status == 'confirmed')
            .toList();
        final slotTerisi = aktif.fold<int>(
            0, (n, b) => n + (b.endMinutes - b.startMinutes) ~/ 60);
        final pemasukan = items
            .where((b) => b.status == 'confirmed')
            .fold<int>(0, (n, b) => n + b.totalPrice);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _stat('Booking\nhari ini', '${aktif.length}'),
              const SizedBox(width: 8),
              _stat('Slot\nterisi', '$slotTerisi'),
              const SizedBox(width: 8),
              _stat('Estimasi\npemasukan', fmtRupiah(pemasukan)),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: DeofootTheme.primary)),
                const SizedBox(height: 4),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, color: DeofootTheme.textMuted)),
              ],
            ),
          ),
        ),
      );
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
            Row(
              children: [
                const Icon(Icons.chat_outlined,
                    size: 14, color: DeofootTheme.textMuted),
                const SizedBox(width: 4),
                Text('WA: ${b.whatsapp.isEmpty ? '-' : b.whatsapp}',
                    style: const TextStyle(
                        fontSize: 13, color: DeofootTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${b.fieldName} • ${b.date} • ${b.startTime}–${b.endTime}',
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
        debugPrint('VerifyScreen._confirm gagal: $e');
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Gagal memproses. Coba lagi.'),
              backgroundColor: DeofootTheme.danger),
        );
      }
    }
  }
}
