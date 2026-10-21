import 'package:flutter/material.dart';

import '../booking_logic.dart';
import '../models.dart';
import '../report_logic.dart';
import '../services/firestore_service.dart';
import '../services/report_pdf_service.dart';
import '../theme.dart';
import '../widgets/pitch_components.dart';

/// Layar Laporan (admin, Fase B v0.4): agregat booking Disetujui per
/// rentang tanggal (hari ini / 7 hari terakhir / bulan ini / pilihan),
/// jumlah per status, okupansi per lapangan, rincian per tanggal,
/// dan export PDF.
/// (Fase G §3.8: kartu Pitch, chip rentang Pitch, angka ringkasan
/// number ticker dari 0 ±600 ms. Agregasi tidak berubah.)
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  JenisRentang _jenis = JenisRentang.hariIni;
  DateTime? _pilMulai;
  DateTime? _pilAkhir;
  bool _exporting = false;

  (DateTime, DateTime) get _rentang {
    if (_jenis == JenisRentang.pilihan) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return (_pilMulai ?? today, _pilAkhir ?? _pilMulai ?? today);
    }
    return rentangPreset(_jenis, DateTime.now());
  }

  String get _labelPeriode {
    final (m, a) = _rentang;
    if (m == a) return tanggalIndonesia(m);
    return '${m.day} ${namaBulan(m.month)} ${m.year} – ${a.day} ${namaBulan(a.month)} ${a.year}';
  }

  Future<void> _pilihTanggal(bool mulai) async {
    final (m0, a0) = _rentang;
    final picked = await showDatePicker(
      context: context,
      initialDate: mulai ? m0 : a0,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() {
      if (mulai) {
        _pilMulai = picked;
        if (_pilAkhir != null && _pilAkhir!.isBefore(picked)) {
          _pilAkhir = picked;
        }
      } else {
        _pilAkhir = picked;
        if (_pilMulai != null && _pilMulai!.isAfter(picked)) {
          _pilMulai = picked;
        }
      }
    });
  }

  Future<void> _export(LaporanPeriode lap) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await ReportPdfService().bagikan(lap: lap, labelPeriode: _labelPeriode);
    } catch (e) {
      debugPrint('ReportScreen._export gagal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuat PDF. Coba lagi.'),
            backgroundColor: DeofootTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (mulai, akhir) = _rentang;
    final fs = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: StreamBuilder<List<Booking>>(
        stream: fs.watchBookingsInRange(fmtDate(mulai), fmtDate(akhir)),
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final lap = hitungLaporan(snap.data ?? [], mulai, akhir);
          final tanggalUrut = lap.pendapatanPerTanggal.keys.toList()..sort();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Pilihan rentang
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(JenisRentang.hariIni, 'Hari ini'),
                  _chip(JenisRentang.tujuhHariTerakhir, '7 hari terakhir'),
                  _chip(JenisRentang.bulanIni, 'Bulan ini'),
                  _chip(JenisRentang.pilihan, 'Pilih tanggal'),
                ],
              ),
              if (_jenis == JenisRentang.pilihan) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pilihTanggal(true),
                        icon: const Icon(Icons.calendar_today_outlined,
                            size: 18),
                        label: Text('Dari: ${fmtDate(mulai)}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DeofootTheme.pitch700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                DeofootTheme.radiusButton),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pilihTanggal(false),
                        icon: const Icon(Icons.calendar_today_outlined,
                            size: 18),
                        label: Text('Sampai: ${fmtDate(akhir)}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DeofootTheme.pitch700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                DeofootTheme.radiusButton),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _labelPeriode,
                style: const TextStyle(color: DeofootTheme.textMuted),
              ),
              const SizedBox(height: 12),
              if (loading)
                const PitchSkeletonCard()
              else ...[
                // Ringkasan — angka menghitung dari 0 (§3.8).
                Row(
                  children: [
                    _stat('Booking\nDisetujui', lap.jumlahBooking,
                        (v) => '$v'),
                    const SizedBox(width: 8),
                    _stat('Slot\nterisi', lap.slotTerisi, (v) => '$v jam'),
                    const SizedBox(width: 8),
                    _stat('Pendapatan', lap.pendapatan, fmtRupiah),
                  ],
                ),
                const Text(
                  'Pendapatan hanya dari booking Disetujui.',
                  style:
                      TextStyle(fontSize: 12, color: DeofootTheme.textMuted),
                ),
                const SizedBox(height: 12),
                // Jumlah booking per status (spek B3).
                Text(
                  'Jumlah per Status',
                  style: DeofootTheme.bodyStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DeofootTheme.pitch900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in const [
                      'confirmed',
                      'pending',
                      'rejected',
                      'cancelled',
                      'expired',
                    ])
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: DeofootTheme.statusColor(s),
                          radius: 6,
                        ),
                        label: Text(
                            '${DeofootTheme.statusLabel(s)}: ${lap.jumlahPerStatus[s] ?? 0}'),
                        backgroundColor: DeofootTheme.surfacePitch,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Per Lapangan',
                  style: DeofootTheme.bodyStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DeofootTheme.pitch900,
                  ),
                ),
                const SizedBox(height: 8),
                if (lap.perLapangan.isEmpty)
                  const Text('Tidak ada booking Disetujui pada periode ini.',
                      style: TextStyle(color: DeofootTheme.textMuted))
                else
                  for (final a in lap.perLapangan)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PitchCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(a.fieldName,
                                      style: DeofootTheme.bodyStyle
                                          .copyWith(
                                              fontWeight:
                                                  FontWeight.w700)),
                                  Text(
                                    '${a.jumlahBooking} booking • Okupansi '
                                    '${a.okupansiPersen.toStringAsFixed(1)}%',
                                    style: DeofootTheme.captionStyle
                                        .copyWith(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              fmtRupiah(a.pendapatan),
                              style: DeofootTheme.tabular(
                                DeofootTheme.bodyStyle.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
                Text(
                  'Per Tanggal',
                  style: DeofootTheme.bodyStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DeofootTheme.pitch900,
                  ),
                ),
                const SizedBox(height: 8),
                if (tanggalUrut.isEmpty)
                  const Text('Tidak ada data.',
                      style: TextStyle(color: DeofootTheme.textMuted))
                else
                  for (final t in tanggalUrut)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PitchCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tanggalIndonesia(DateTime.parse(t)),
                                    style: DeofootTheme.bodyStyle
                                        .copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${lap.bookingPerTanggal[t] ?? 0} booking',
                                    style: DeofootTheme.captionStyle
                                        .copyWith(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              fmtRupiah(lap.pendapatanPerTanggal[t] ?? 0),
                              style: DeofootTheme.tabular(
                                DeofootTheme.bodyStyle.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                PitchButton(
                  label: _exporting ? 'Membuat PDF…' : 'Export PDF',
                  onPressed: _exporting ? null : () => _export(lap),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _chip(JenisRentang jenis, String label) {
    return PitchChip(
      label: label,
      selected: _jenis == jenis,
      onTap: () => setState(() => _jenis = jenis),
    );
  }

  Widget _stat(String label, int value, String Function(int) format) =>
      Expanded(
        child: PitchCard(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              NumberTicker(
                value: value,
                format: format,
                fromZero: true,
                duration: const Duration(milliseconds: 600),
                style: DeofootTheme.tabular(
                  DeofootTheme.bodyStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DeofootTheme.pitch900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: DeofootTheme.textMuted)),
            ],
          ),
        ),
      );
}
