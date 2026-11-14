import 'package:deofoot/models.dart';
import 'package:deofoot/report_logic.dart';
import 'package:deofoot/services/report_pdf_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Booking booking({
    required String id,
    required String fieldId,
    required String fieldName,
    required String date,
    required int totalPrice,
    String status = 'confirmed',
  }) {
    return Booking(
      id: id,
      userId: 'u1',
      userEmail: 'u@test.com',
      fieldId: fieldId,
      fieldName: fieldName,
      date: date,
      startTime: '19:00',
      endTime: '20:00',
      status: status,
      totalPrice: totalPrice,
      pricePerHour: 120000,
      createdAt: DateTime(2026, 10, 20),
    );
  }

  test(
    'buildPdf dengan data: tabel per lapangan + per tanggal terisi',
    () async {
      final lap = hitungLaporan(
        [
          booking(
            id: 'b1',
            fieldId: 'l1',
            fieldName: 'Lapangan 1',
            date: '2026-10-20',
            totalPrice: 120000,
          ),
          booking(
            id: 'b2',
            fieldId: 'p1',
            fieldName: 'Padel 1',
            date: '2026-10-21',
            totalPrice: 500000,
          ),
          booking(
            id: 'b3',
            fieldId: 'l1',
            fieldName: 'Lapangan 1',
            date: '2026-10-20',
            totalPrice: 120000,
            status: 'pending',
          ),
        ],
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 25),
      );
      expect(lap.perLapangan, isNotEmpty);
      expect(lap.pendapatanPerTanggal, isNotEmpty);
      final bytes = await ReportPdfService().buildPdf(
        lap: lap,
        labelPeriode: '19 Oktober 2026 – 25 Oktober 2026',
        tanggalCetak: DateTime(2026, 10, 21),
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
  );

  test('bagikan membuka lembar sistem (channel printing dimock)', () async {
    const channel = MethodChannel('net.nfet.printing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 1);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final lap = hitungLaporan(
      const [],
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 25),
    );
    await ReportPdfService().bagikan(
      lap: lap,
      labelPeriode: '19 Oktober 2026 – 25 Oktober 2026',
    );
  });
}
