import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../report_logic.dart';
import '../services/firestore_service.dart';
import '../services/report_pdf_service.dart';

/// Layar Laporan (admin, Fase B v0.4): agregat booking Disetujui per
/// rentang tanggal (hari ini / minggu ini / bulan ini / pilihan),
/// rincian per lapangan & per tanggal, dan export PDF.
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
                children: [
                  _chip(JenisRentang.hariIni, 'Hari ini'),
                  _chip(JenisRentang.mingguIni, 'Minggu ini'),
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
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text('Dari: ${fmtDate(mulai)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pilihTanggal(false),
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text('Sampai: ${fmtDate(akhir)}'),
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
                const Center(child: CircularProgressIndicator())
              else ...[
                // Ringkasan
                Row(
                  children: [
                    _stat('Booking\nDisetujui', '${lap.jumlahBooking}'),
                    const SizedBox(width: 8),
                    _stat('Slot\nterisi', '${lap.slotTerisi} jam'),
                    const SizedBox(width: 8),
                    _stat('Pendapatan', fmtRupiah(lap.pendapatan)),
                  ],
                ),
                const Text(
                  'Hanya booking Disetujui yang dihitung.',
                  style: TextStyle(fontSize: 12, color: DeofootTheme.textMuted),
                ),
                const SizedBox(height: 16),
                const Text('Per Lapangan',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DeofootTheme.primary)),
                const SizedBox(height: 8),
                if (lap.perLapangan.isEmpty)
                  const Text('Tidak ada booking Disetujui pada periode ini.',
                      style: TextStyle(color: DeofootTheme.textMuted))
                else
                  for (final a in lap.perLapangan)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(a.fieldName),
                        subtitle: Text('${a.jumlahBooking} booking'),
                        trailing: Text(
                          fmtRupiah(a.pendapatan),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
                const Text('Per Tanggal',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DeofootTheme.primary)),
                const SizedBox(height: 8),
                if (tanggalUrut.isEmpty)
                  const Text('Tidak ada data.',
                      style: TextStyle(color: DeofootTheme.textMuted))
                else
                  for (final t in tanggalUrut)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(tanggalIndonesia(DateTime.parse(t))),
                        subtitle:
                            Text('${lap.bookingPerTanggal[t] ?? 0} booking'),
                        trailing: Text(
                          fmtRupiah(lap.pendapatanPerTanggal[t] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _exporting ? null : () => _export(lap),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_exporting ? 'Membuat PDF…' : 'Export PDF'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _chip(JenisRentang jenis, String label) {
    final sel = _jenis == jenis;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => setState(() => _jenis = jenis),
      selectedColor: DeofootTheme.primary,
      labelStyle: TextStyle(
        color: sel ? Colors.white : DeofootTheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 16,
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
