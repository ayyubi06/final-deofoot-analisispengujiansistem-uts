import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../booking_logic.dart';
import '../report_logic.dart';

/// Label periode KHUSUS PDF (Fase G §3.8, perbaikan wajib):
/// en-dash "–" tampil sebagai kotak di PDF v0.4 (glyph tidak ada
/// di font standar PDF), jadi rentang ditulis dengan "s.d.".
/// Label di layar aplikasi tidak berubah — hanya salinan PDF.
String labelPeriodePdf(String label) => label.replaceAll('–', 's.d.');

/// Pembuat PDF laporan admin (Fase B v0.4) dari hasil agregasi murni
/// [LaporanPeriode]. PDF dapat dibagikan / disimpan / dicetak lewat
/// package printing.
class ReportPdfService {
  /// Susun dokumen PDF laporan. [labelPeriode] teks manusiawi, mis.
  /// "Rabu, 21 Oktober 2026" atau "19 Oktober 2026 – 25 Oktober 2026"
  /// (di dalam PDF, "–" diganti "s.d." — lihat [labelPeriodePdf]).
  Future<Uint8List> buildPdf({
    required LaporanPeriode lap,
    required String labelPeriode,
    required DateTime tanggalCetak,
  }) async {
    final doc = pw.Document();
    final tanggalUrut = lap.pendapatanPerTanggal.keys.toList()..sort();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          pw.Text('Laporan Deofoot',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Periode: ${labelPeriodePdf(labelPeriode)}'),
          pw.Text('Dicetak: ${tanggalIndonesia(tanggalCetak)}'),
          pw.SizedBox(height: 16),
          pw.Text('Ringkasan', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Jumlah booking (Disetujui)', 'Slot terisi', 'Total pendapatan'],
            data: [
              [
                '${lap.jumlahBooking}',
                '${lap.slotTerisi} jam',
                fmtRupiah(lap.pendapatan),
              ]
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Jumlah booking per status',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: const ['Disetujui', 'Menunggu', 'Ditolak', 'Dibatalkan', 'Kedaluwarsa'],
            data: [
              [
                '${lap.jumlahPerStatus['confirmed'] ?? 0}',
                '${lap.jumlahPerStatus['pending'] ?? 0}',
                '${lap.jumlahPerStatus['rejected'] ?? 0}',
                '${lap.jumlahPerStatus['cancelled'] ?? 0}',
                '${lap.jumlahPerStatus['expired'] ?? 0}',
              ]
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Per Lapangan', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (lap.perLapangan.isEmpty)
            pw.Text('Tidak ada booking Disetujui pada periode ini.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Lapangan', 'Booking', 'Okupansi', 'Pendapatan'],
              data: [
                for (final a in lap.perLapangan)
                  [
                    a.fieldName,
                    '${a.jumlahBooking}',
                    '${a.okupansiPersen.toStringAsFixed(1)}%',
                    fmtRupiah(a.pendapatan),
                  ]
              ],
            ),
          pw.SizedBox(height: 16),
          pw.Text('Per Tanggal', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (tanggalUrut.isEmpty)
            pw.Text('Tidak ada data.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Tanggal', 'Booking', 'Pendapatan'],
              data: [
                for (final t in tanggalUrut)
                  [
                    tanggalIndonesia(DateTime.parse(t)),
                    '${lap.bookingPerTanggal[t] ?? 0}',
                    fmtRupiah(lap.pendapatanPerTanggal[t] ?? 0),
                  ]
              ],
            ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Catatan: pendapatan hanya dari booking Disetujui.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            'Dihasilkan oleh aplikasi Deofoot.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Bangun PDF lalu buka lembar bagai/cetak sistem.
  Future<void> bagikan({
    required LaporanPeriode lap,
    required String labelPeriode,
  }) async {
    final bytes = await buildPdf(
      lap: lap,
      labelPeriode: labelPeriode,
      tanggalCetak: DateTime.now(),
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'laporan-deofoot_${fmtDate(lap.mulai)}_${fmtDate(lap.akhir)}.pdf',
    );
  }
}
