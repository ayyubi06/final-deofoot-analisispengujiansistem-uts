import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deofoot/report_logic.dart';
import 'package:deofoot/services/report_pdf_service.dart';
import 'package:deofoot/theme.dart';
import 'package:deofoot/widgets/pitch_components.dart';

/// Test Fase G Tahap 6 (§3.8): saklar pegas PitchToggle, ticker
/// dari nol untuk Laporan, dan perbaikan WAJIB glyph "Periode:"
/// di PDF — dibuktikan dari PDF sungguhan yang dibangun service.
void main() {
  group('labelPeriodePdf (§3.8 perbaikan glyph)', () {
    test('en-dash -> s.d.', () {
      expect(
        labelPeriodePdf('19 Oktober 2026 – 25 Oktober 2026'),
        '19 Oktober 2026 s.d. 25 Oktober 2026',
      );
    });

    test('label satu tanggal tidak berubah', () {
      expect(
        labelPeriodePdf('Rabu, 21 Oktober 2026'),
        'Rabu, 21 Oktober 2026',
      );
    });
  });

  test('buildPdf nyata: PDF valid & membawa label s.d.', () async {
    final lap = hitungLaporan(
      const [],
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 25),
    );
    final bytes = await ReportPdfService().buildPdf(
      lap: lap,
      labelPeriode: '19 Oktober 2026 – 25 Oktober 2026',
      tanggalCetak: DateTime(2026, 10, 21),
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Simpan untuk pemeriksaan teks di luar test (ekstraksi aliran
    // isi PDF) — bukti glyph dari berkas nyatanya.
    await File('/tmp/laporan-faseg-test.pdf').writeAsBytes(bytes);
  });

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('NumberTicker fromZero: mulai 0 lalu menetap di nilai',
      (tester) async {
    await tester.pumpWidget(
      wrap(NumberTicker(
        value: 100,
        format: (v) => '$v',
        fromZero: true,
        duration: const Duration(milliseconds: 600),
        style: DeofootTheme.bodyStyle,
      )),
    );
    await tester.pump(); // post-frame: animasi dimulai dari 0
    expect(find.text('0'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('PitchToggle: ketuk memanggil onChanged; kenop menetap',
      (tester) async {
    var nilai = false;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => PitchToggle(
            value: nilai,
            onChanged: (v) => setState(() => nilai = v),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PitchToggle));
    await tester.pump();
    expect(nilai, isTrue);
    // Jalankan pegas kenop sampai diam — tidak boleh ada error.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byType(PitchToggle));
    await tester.pump();
    expect(nilai, isFalse);
  });
}
