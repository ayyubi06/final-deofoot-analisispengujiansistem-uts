import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/screens/verify_screen.dart';

// PNG 1x1 transparan untuk fixture bukti bayar.
const _png1px =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

SubscriptionSeries _seri() => SubscriptionSeries(
      id: 'seriA',
      userId: 'u1',
      userEmail: 'budi@test.id',
      fieldId: 'l1',
      fieldName: 'Futsal L1',
      weekday: 1,
      startTime: '19:00',
      endTime: '20:00',
      pricePerHour: 120000,
      totalPerMeeting: 120000,
      meetingsTotal: 3,
      startDate: '2026-11-02',
      endDate: '2026-11-16',
      meetingDates: const ['2026-11-02', '2026-11-09', '2026-11-16'],
      whatsapp: '081234567890',
      proofBase64: _png1px,
      status: 'pending',
      cancelledMeetingDates: const ['2026-11-09'],
      createdAt: DateTime(2026, 10, 21),
    );

Booking _m(String id, String date, String status, int idx) => Booking(
      id: id,
      userId: 'u1',
      userEmail: 'budi@test.id',
      fieldId: 'l1',
      fieldName: 'Futsal L1',
      date: date,
      startTime: '19:00',
      endTime: '20:00',
      status: status,
      totalPrice: 120000,
      seriesId: 'seriA',
      seriesIndex: idx,
      createdAt: DateTime(2026, 10, 21),
    );

List<Booking> _meetings() => [
      _m('m1', '2026-11-02', 'pending', 1),
      _m('m2', '2026-11-09', 'cancelled', 2),
      _m('m3', '2026-11-16', 'pending', 3),
    ];

Future<void> _pump(WidgetTester tester, List<bool> decisions) async {
  tester.view.physicalSize = const Size(1080, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SeriesDetailView(
          series: _seri(),
          meetings: _meetings(),
          onDecision: decisions.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(b) rincian seri merender daftar pertemuan + bukti',
      (tester) async {
    await _pump(tester, []);
    // Bukti bayar seri tampil sebagai gambar.
    expect(find.byType(Image), findsOneWidget);
    // Pemesan + WA.
    expect(find.text('budi@test.id'), findsOneWidget);
    expect(find.text('WA: 081234567890'), findsOneWidget);
    // Semua tanggal pertemuan tampil (Senin-senin November 2026).
    expect(find.textContaining('Senin, 2 November 2026'), findsOneWidget);
    expect(find.textContaining('Senin, 9 November 2026'), findsOneWidget);
    expect(find.textContaining('Senin, 16 November 2026'), findsOneWidget);
    // Status masing-masing: 2 Menunggu, 1 Dibatalkan.
    expect(find.text('Menunggu'), findsNWidgets(2));
    expect(find.text('Dibatalkan'), findsOneWidget);
    // Total seri 3 x Rp120.000.
    expect(find.text('Rp360.000'), findsOneWidget);
  });

  testWidgets(
      '(c) Terima dari rincian: dialog menyebut cancelled utuh, '
      'keputusan confirmed terkirim satu kali', (tester) async {
    final decisions = <bool>[];
    await _pump(tester, decisions);
    await tester.ensureVisible(find.text('Terima seri'));
    await tester.tap(find.text('Terima seri'));
    await tester.pumpAndSettle();
    // Dialog: 2 pending ikut disetujui; 1 yang sudah berubah status
    // (cancelled) tidak ikut berubah.
    expect(
      find.textContaining(
          '2 pertemuan yang masih menunggu akan ikut disetujui'),
      findsOneWidget,
    );
    expect(find.textContaining('tidak ikut berubah'), findsOneWidget);
    await tester.tap(find.text('Ya, terima'));
    await tester.pumpAndSettle();
    expect(decisions, [true]);
  });

  testWidgets('(c2) Tolak dari rincian mengirim keputusan rejected',
      (tester) async {
    final decisions = <bool>[];
    await _pump(tester, decisions);
    await tester.ensureVisible(find.text('Tolak seri'));
    await tester.tap(find.text('Tolak seri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, tolak'));
    await tester.pumpAndSettle();
    expect(decisions, [false]);
  });
}
