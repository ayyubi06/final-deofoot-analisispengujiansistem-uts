import 'dart:convert';

import 'package:deofoot/services/report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  test('replaces unsupported en dash only in PDF period labels', () {
    expect(labelPeriodePdf('18–24 November 2026'), '18s.d.24 November 2026');
    expect(labelPeriodePdf('Rabu, 18 November 2026'), 'Rabu, 18 November 2026');
  });

  test(
    'builds a PDF report with populated summary and detail tables',
    () async {
      final bytes = await ReportPdfService().buildPdf(
        lap: TestFixtures.report(),
        labelPeriode: '18–18 November 2026',
        tanggalCetak: DateTime(2026, 11, 14),
      );

      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(500));
    },
  );

  test('builds a valid PDF for empty report details', () async {
    final bytes = await ReportPdfService().buildPdf(
      lap: TestFixtures.report(populated: false),
      labelPeriode: '18 November 2026',
      tanggalCetak: DateTime(2026, 11, 14),
    );

    expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });

  test(
    'shares generated PDF using the report date range in its filename',
    () async {
      TestFixtures.installPrintingShareMock();
      addTearDown(TestFixtures.removePrintingShareMock);

      await ReportPdfService().bagikan(
        lap: TestFixtures.report(),
        labelPeriode: '18 November 2026',
      );

      final call = TestFixtures.lastPrintingCall;
      expect(call?.method, 'sharePdf');
      expect(
        (call?.arguments as Map)['name'],
        'laporan-deofoot_2026-11-18_2026-11-18.pdf',
      );
      expect((call?.arguments as Map)['doc'], isNotEmpty);
    },
  );
}
