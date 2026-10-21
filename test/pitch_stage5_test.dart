import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deofoot/models.dart';
import 'package:deofoot/screens/recurring_screen.dart';
import 'package:deofoot/screens/user_series_screen.dart';

/// Test Fase G Tahap 5 (§3.6–§3.7): progres form langganan dan
/// rincian seri pengguna (stream disuntik — murni presentasi).
void main() {
  group('recurringProgress (§3.7)', () {
    test('kosong -> 0; satu gerbang -> 0,5; lengkap -> 1', () {
      expect(recurringProgress(waValid: false, hasProof: false), 0);
      expect(recurringProgress(waValid: true, hasProof: false), 0.5);
      expect(recurringProgress(waValid: false, hasProof: true), 0.5);
      expect(recurringProgress(waValid: true, hasProof: true), 1);
    });
  });

  Booking bk(String id, String date, String status) => Booking(
        id: id,
        userId: 'u1',
        userEmail: 'u@test.id',
        fieldId: 'f1',
        fieldName: 'Lapangan Futsal A',
        date: date,
        startTime: '19:00',
        endTime: '20:00',
        whatsapp: '081234567890',
        proofBase64: '',
        totalPrice: 120000,
        pricePerHour: 120000,
        status: status,
        seriesId: 's1',
        createdAt: DateTime(2026, 10, 1),
      );

  testWidgets('UserSeriesScreen: pertemuan terurut + chip status',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserSeriesScreen(
          fieldName: 'Lapangan Futsal A',
          meetingsStream: Stream.value([
            bk('b2', '2026-10-28', 'pending'),
            bk('b1', '2026-10-21', 'confirmed'),
          ]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Lapangan Futsal A'), findsOneWidget);
    expect(find.text('Langganan'), findsOneWidget);
    expect(find.text('2 pertemuan'), findsOneWidget);
    // Terurut menaik: 21 Okt (Disetujui) sebelum 28 Okt (Menunggu).
    expect(find.text('Disetujui'), findsOneWidget);
    expect(find.text('Menunggu'), findsOneWidget);
    final y21 = tester.getTopLeft(find.textContaining('21 Oktober')).dy;
    final y28 = tester.getTopLeft(find.textContaining('28 Oktober')).dy;
    expect(y21, lessThan(y28));
  });

  testWidgets('UserSeriesScreen: kosong -> kalimat kosong',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserSeriesScreen(
          fieldName: 'Lapangan Futsal A',
          meetingsStream: Stream.value(const []),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Belum ada pertemuan.'), findsOneWidget);
    expect(find.text('0 pertemuan'), findsOneWidget);
  });
}
