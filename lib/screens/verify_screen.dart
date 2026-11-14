import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../booking_logic.dart';
import '../models.dart';
import '../report_logic.dart' show namaHari, tanggalIndonesia;
import '../services/firestore_service.dart';
import '../theme.dart';
import '../verify_logic.dart';
import '../widgets/pitch_components.dart';

/// Layar 8 — Verifikasi (admin): list booking pending individual +
/// Terima/Tolak, dan seri langganan pending yang dikonfirmasi SATU
/// kali per seri lewat rincian seri (Fase E + Addendum 4 SPEK-V04).
/// (Fase G §3.8: kartu Pitch, rincian seri sebagai sheet layar
/// penuh, thumbnail bukti -> pratinjau penuh shared element.)
class VerifyScreen extends StatelessWidget {
  final FirestoreService firestoreService;

  VerifyScreen({super.key, FirestoreService? firestoreService})
    : firestoreService = firestoreService ?? FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Pembayaran')),
      body: Column(
        children: [
          _Dashboard(firestoreService: firestoreService),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTitle('Booking menunggu'),
                _PendingBookings(firestoreService: firestoreService),
                SizedBox(height: 8),
                _SectionTitle('Langganan menunggu'),
                _PendingSeries(firestoreService: firestoreService),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pratinjau bukti transfer layar penuh (§3.8): tujuan Hero dari
/// thumbnail di kartu verifikasi & rincian seri.
class ProofPreviewScreen extends StatelessWidget {
  final String heroTag;
  final Uint8List bytes;
  const ProofPreviewScreen({
    super.key,
    required this.heroTag,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeofootTheme.pitch900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Bukti transfer',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
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
        style: DeofootTheme.bodyStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: DeofootTheme.pitch900,
        ),
      ),
    );
  }
}

class _PendingBookings extends StatelessWidget {
  final FirestoreService firestoreService;

  const _PendingBookings({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: firestoreService.watchPending(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const PitchSkeletonCard();
        }
        // Pertemuan seri TIDAK tampil di sini — seri dikonfirmasi
        // satu kali lewat kartu seri (Addendum 4).
        final items = bookingVerifikasiIndividual(snap.data ?? []);
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Tidak ada booking menunggu verifikasi.',
              style: TextStyle(color: DeofootTheme.textMuted),
            ),
          );
        }
        return Column(
          children: [
            for (final b in items)
              _PendingCard(booking: b, firestoreService: firestoreService),
          ],
        );
      },
    );
  }
}

class _PendingSeries extends StatelessWidget {
  final FirestoreService firestoreService;

  const _PendingSeries({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SubscriptionSeries>>(
      stream: firestoreService.watchPendingSeries(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const PitchSkeletonCard();
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Text(
            'Tidak ada langganan menunggu verifikasi.',
            style: TextStyle(color: DeofootTheme.textMuted),
          );
        }
        return Column(
          children: [
            for (final s in items)
              _SeriesCard(series: s, firestoreService: firestoreService),
          ],
        );
      },
    );
  }
}

/// Buka rincian seri sebagai SHEET layar penuh (§3.8) — isi &
/// keputusan sama dengan SeriesDetailScreen; Terima/Tolak tetap
/// satu kali per seri lewat setSeriesStatus.
void _openSeriesSheet(
  BuildContext context,
  SubscriptionSeries s,
  FirestoreService firestoreService,
) {
  showPitchSheet<void>(
    context,
    isScrollControlled: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.92,
      child: StreamBuilder<List<Booking>>(
        stream: firestoreService.watchBookingsBySeries(s.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: PitchSkeletonCard(),
            );
          }
          final meetings = pertemuanSeriUrut(snap.data ?? []);
          return SeriesDetailView(
            series: s,
            meetings: meetings,
            onDecision: (terima) async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(sheetContext);
              try {
                await firestoreService.setSeriesStatus(
                  s.id,
                  terima ? 'confirmed' : 'rejected',
                );
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      terima
                          ? 'Seri disetujui, semua pertemuan aktif.'
                          : 'Seri ditolak, semua slot kembali bebas.',
                    ),
                  ),
                );
              } catch (e) {
                debugPrint('SeriesSheet._proses gagal: $e');
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Gagal memproses. Coba lagi.'),
                    backgroundColor: DeofootTheme.danger,
                  ),
                );
              }
            },
          );
        },
      ),
    ),
  );
}

/// Kartu ringkas seri langganan pending (Addendum 4): pemesan,
/// lapangan, pola hari + jam, jumlah pertemuan, total seri.
/// Diketuk -> rincian seri (sheet); konfirmasi HANYA dari rincian.
class _SeriesCard extends StatelessWidget {
  final SubscriptionSeries series;
  final FirestoreService firestoreService;

  const _SeriesCard({required this.series, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    final s = series;
    final hari = s.meetingDates.isNotEmpty
        ? namaHari(DateTime.parse(s.meetingDates.first))
        : '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PitchCard(
        onTap: () => _openSeriesSheet(context, s, firestoreService),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.repeat,
                        size: 18,
                        color: DeofootTheme.pitch700,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Langganan rutin',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${s.meetingsTotal} pertemuan',
                        style: const TextStyle(color: DeofootTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.userEmail,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.fieldName} \u2022 setiap $hari ${s.startTime}\u2013${s.endTime}',
                    style: const TextStyle(color: DeofootTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: ${fmtRupiah(s.totalHarga)}',
                    style: DeofootTheme.tabular(
                      DeofootTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DeofootTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Layar Rincian Langganan (Addendum 4): bukti bayar seri + daftar
/// semua pertemuan beserta statusnya; Terima/Tolak seri SATU kali
/// dari sini -> setSeriesStatus yang sudah ada (atomik; pertemuan
/// cancelled tidak ikut berubah). (Di Fase G, kartu seri membuka
/// isi yang sama sebagai sheet — layar ini dipertahankan.)
class SeriesDetailScreen extends StatelessWidget {
  final SubscriptionSeries series;
  final FirestoreService firestoreService;

  SeriesDetailScreen({
    super.key,
    required this.series,
    FirestoreService? firestoreService,
  }) : firestoreService = firestoreService ?? FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rincian Langganan')),
      body: StreamBuilder<List<Booking>>(
        stream: firestoreService.watchBookingsBySeries(series.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: PitchSkeletonCard(),
            );
          }
          final meetings = pertemuanSeriUrut(snap.data ?? []);
          return SeriesDetailView(
            series: series,
            meetings: meetings,
            onDecision: (terima) => _proses(context, terima),
          );
        },
      ),
    );
  }

  Future<void> _proses(BuildContext context, bool terima) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await firestoreService.setSeriesStatus(
        series.id,
        terima ? 'confirmed' : 'rejected',
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            terima
                ? 'Seri disetujui, semua pertemuan aktif.'
                : 'Seri ditolak, semua slot kembali bebas.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('SeriesDetailScreen._proses gagal: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal memproses. Coba lagi.'),
          backgroundColor: DeofootTheme.danger,
        ),
      );
    }
  }
}

/// Isi rincian seri (presentasional murni — data diberikan, keputusan
/// dikembalikan lewat [onDecision]): pemesan + WA, bukti bayar seri,
/// info pola, daftar pertemuan + status, total, dan tombol
/// Terima/Tolak seri dengan dialog konfirmasi.
class SeriesDetailView extends StatelessWidget {
  final SubscriptionSeries series;
  final List<Booking> meetings;
  final ValueChanged<bool> onDecision;
  const SeriesDetailView({
    super.key,
    required this.series,
    required this.meetings,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    final s = series;
    final hari = s.meetingDates.isNotEmpty
        ? namaHari(DateTime.parse(s.meetingDates.first))
        : '-';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bukti(context),
        const SizedBox(height: 12),
        Text(
          s.userEmail,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.chat_outlined,
              size: 14,
              color: DeofootTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'WA: ${s.whatsapp.isEmpty ? '-' : s.whatsapp}',
              style: const TextStyle(
                fontSize: 13,
                color: DeofootTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${s.fieldName} \u2022 setiap $hari ${s.startTime}\u2013${s.endTime}',
          style: const TextStyle(color: DeofootTheme.textMuted),
        ),
        Text(
          '${s.startDate} s/d ${s.endDate} \u2022 ${s.meetingsTotal} pertemuan',
          style: const TextStyle(color: DeofootTheme.textMuted),
        ),
        const SizedBox(height: 16),
        Text(
          'Daftar pertemuan',
          style: DeofootTheme.bodyStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: DeofootTheme.pitch900,
          ),
        ),
        const SizedBox(height: 8),
        if (meetings.isEmpty)
          const Text(
            'Belum ada data pertemuan.',
            style: TextStyle(color: DeofootTheme.textMuted),
          )
        else
          for (final b in meetings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PitchCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tanggalIndonesia(DateTime.parse(b.date))} \u2022 ${b.startTime}\u2013${b.endTime}',
                        style: DeofootTheme.bodyStyle,
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: DeofootTheme.statusColor(b.status),
                      radius: 5,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DeofootTheme.statusLabel(b.status),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total seri',
              style: TextStyle(color: DeofootTheme.textMuted),
            ),
            Text(
              fmtRupiah(s.totalHarga),
              style: DeofootTheme.tabular(
                DeofootTheme.titleStyle.copyWith(color: DeofootTheme.pitch700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PitchButton(
                label: 'Terima seri',
                onPressed: () => _confirm(context, true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PitchButton(
                label: 'Tolak seri',
                variant: PitchButtonVariant.danger,
                onPressed: () => _confirm(context, false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bukti(BuildContext context) {
    final s = series;
    if (s.proofBase64 != null && s.proofBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(s.proofBase64!);
        final tag = 'proof-series-${s.id}';
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProofPreviewScreen(heroTag: tag, bytes: bytes),
            ),
          ),
          child: Hero(
            tag: tag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DeofootTheme.radiusCard),
              child: Image.memory(
                bytes,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      } catch (_) {
        // jatuh ke placeholder di bawah
      }
    }
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: DeofootTheme.surfacePitch,
        borderRadius: BorderRadius.circular(DeofootTheme.radiusCard),
      ),
      child: const Center(
        child: Text(
          'Bukti tidak tersedia',
          style: TextStyle(color: DeofootTheme.textMuted),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, bool terima) async {
    final ikut = jumlahPertemuanIkutBerubah(meetings);
    final utuh = pertemuanTidakBerubah(meetings).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          terima ? 'Terima seri langganan?' : 'Tolak seri langganan?',
        ),
        content: Text(
          (terima
                  ? 'Seluruh seri ${series.userEmail} (${series.fieldName}) akan DISETUJUI. '
                        '$ikut pertemuan yang masih menunggu akan ikut disetujui.'
                  : 'Seluruh seri ${series.userEmail} (${series.fieldName}) akan DITOLAK dan slotnya kembali bebas. '
                        '$ikut pertemuan yang masih menunggu akan ikut ditolak.') +
              (utuh > 0
                  ? ' $utuh pertemuan yang sudah berubah status (mis. dibatalkan) tidak ikut berubah.'
                  : ''),
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
    if (ok == true) onDecision(terima);
  }
}

/// Dashboard mini admin: 3 angka hari ini, real-time dari Firestore.
class _Dashboard extends StatelessWidget {
  final FirestoreService firestoreService;

  const _Dashboard({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: firestoreService.watchBookingsToday(),
      builder: (context, snap) {
        final items = snap.data ?? [];
        final aktif = items
            .where((b) => b.status == 'pending' || b.status == 'confirmed')
            .toList();
        final slotTerisi = aktif.fold<int>(
          0,
          (n, b) => n + (b.endMinutes - b.startMinutes) ~/ 60,
        );
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
    child: PitchCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        children: [
          Text(
            value,
            style: DeofootTheme.tabular(
              DeofootTheme.bodyStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DeofootTheme.pitch900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: DeofootTheme.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _PendingCard extends StatelessWidget {
  final Booking booking;
  final FirestoreService firestoreService;

  const _PendingCard({required this.booking, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PitchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(context),
            const SizedBox(height: 12),
            Text(
              b.userEmail,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.chat_outlined,
                  size: 14,
                  color: DeofootTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'WA: ${b.whatsapp.isEmpty ? '-' : b.whatsapp}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: DeofootTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${b.fieldName} • ${b.date} • ${b.startTime}–${b.endTime}',
              style: const TextStyle(color: DeofootTheme.textMuted),
            ),
            Text(
              'Total: ${fmtRupiah(b.totalPrice)}',
              style: DeofootTheme.tabular(
                DeofootTheme.bodyStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PitchButton(
                    label: 'Terima',
                    onPressed: () => _confirm(context, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PitchButton(
                    label: 'Tolak',
                    variant: PitchButtonVariant.danger,
                    onPressed: () => _confirm(context, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    final b = booking;
    if (b.proofBase64 != null && b.proofBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(b.proofBase64!);
        final tag = 'proof-${b.id}';
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProofPreviewScreen(heroTag: tag, bytes: bytes),
            ),
          ),
          child: Hero(
            tag: tag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DeofootTheme.radiusCard),
              child: Image.memory(
                bytes,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      } catch (_) {
        // jatuh ke placeholder di bawah
      }
    }
    return _noProof();
  }

  Widget _noProof() => Container(
    height: 80,
    decoration: BoxDecoration(
      color: DeofootTheme.surfacePitch,
      borderRadius: BorderRadius.circular(DeofootTheme.radiusCard),
    ),
    child: const Center(
      child: Text(
        'Bukti tidak tersedia',
        style: TextStyle(color: DeofootTheme.textMuted),
      ),
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
        await firestoreService.setBookingStatus(
          booking.id,
          terima ? 'confirmed' : 'rejected',
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              terima
                  ? 'Booking disetujui.'
                  : 'Booking ditolak, slot kembali bebas.',
            ),
          ),
        );
      } catch (e) {
        debugPrint('VerifyScreen._confirm gagal: $e');
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Gagal memproses. Coba lagi.'),
            backgroundColor: DeofootTheme.danger,
          ),
        );
      }
    }
  }
}
