import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/report_logic.dart';
import 'package:deofoot/screens/verify_screen.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fase2_helpers.dart';

// PNG 1x1 transparan untuk bukti palsu.
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeFirebaseFirestore fake;

  setUp(() {
    fake = FakeFirebaseFirestore();
  });

  FirestoreService fs() => FirestoreService(db: fake);

  Future<void> pumpVerify(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: VerifyScreen(firestoreService: fs())),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    SubscriptionSeries series,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SeriesDetailScreen(series: series, firestoreService: fs()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pompa pendek berulang sampai teks muncul (maks 4 detik).
  /// Dipakai untuk SnackBar yang hilang sendiri (jangan pumpAndSettle).
  Future<void> pollFor(WidgetTester tester, String text) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text(text).evaluate().isNotEmpty) return;
    }
  }

  Future<void> seedSeriesWithMeetings({String status2 = 'pending'}) async {
    await seedSeries(fake);
    await seedBooking(
      fake,
      id: 'm1',
      seriesId: 's1',
      seriesIndex: 0,
      date: '2026-11-21',
      startTime: '19:00',
      endTime: '20:00',
      status: 'pending',
    );
    await seedBooking(
      fake,
      id: 'm2',
      seriesId: 's1',
      seriesIndex: 1,
      date: '2026-11-28',
      startTime: '19:00',
      endTime: '20:00',
      status: status2,
    );
  }

  Future<void> openSeriesSheet(WidgetTester tester) async {
    await tester.tap(find.text('Langganan rutin'));
    await tester.pumpAndSettle();
  }

  testWidgets('tampil kosong tanpa antrean', (tester) async {
    await pumpVerify(tester);

    expect(find.text('Verifikasi Pembayaran'), findsOneWidget);
    expect(find.text('Booking menunggu'), findsOneWidget);
    expect(
      find.text('Tidak ada booking menunggu verifikasi.'),
      findsOneWidget,
    );
    expect(find.text('Langganan menunggu'), findsOneWidget);
    expect(
      find.text('Tidak ada langganan menunggu verifikasi.'),
      findsOneWidget,
    );
    expect(find.text('Booking\nhari ini'), findsOneWidget);
    expect(find.text('Slot\nterisi'), findsOneWidget);
    expect(find.text('Estimasi\npemasukan'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('dashboard menghitung booking hari ini', (tester) async {
    final today = fmtDate(DateTime.now());
    await seedBooking(
      fake,
      id: 'b1',
      status: 'confirmed',
      date: today,
      startTime: '19:00',
      endTime: '20:00',
    );
    await seedBooking(
      fake,
      id: 'b2',
      status: 'pending',
      date: today,
      startTime: '20:00',
      endTime: '21:00',
    );
    await seedBooking(
      fake,
      id: 'b3',
      status: 'rejected',
      date: today,
      startTime: '21:00',
      endTime: '22:00',
    );
    await pumpVerify(tester);

    expect(find.text('2'), findsNWidgets(2));
    expect(find.text(fmtRupiah(120000)), findsOneWidget);
    expect(find.text('Total: ${fmtRupiah(120000)}'), findsOneWidget);
  });

  testWidgets('kartu booking pending dengan bukti', (tester) async {
    await seedBooking(fake, id: 'b1', status: 'pending');
    await fake.collection('bookings').doc('b1').update({
      'proofBase64': _png1x1,
    });
    await pumpVerify(tester);

    expect(find.text('u1@test.com'), findsOneWidget);
    expect(find.text('WA: 08123456789'), findsOneWidget);
    expect(
      find.text('Lapangan 1 • 2026-11-20 • 19:00–20:00'),
      findsOneWidget,
    );
    expect(find.text('Total: ${fmtRupiah(120000)}'), findsOneWidget);
    expect(find.text('Terima'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('kartu booking tanpa bukti menampilkan placeholder',
      (tester) async {
    await seedBooking(fake, id: 'b1', status: 'pending');
    await pumpVerify(tester);

    expect(find.text('Bukti tidak tersedia'), findsOneWidget);
  });

  testWidgets('bukti base64 rusak menampilkan placeholder', (tester) async {
    await seedBooking(fake, id: 'b1', status: 'pending');
    await fake.collection('bookings').doc('b1').update({
      'proofBase64': '!!!bukan-base64!!!',
    });
    await pumpVerify(tester);

    expect(find.text('Bukti tidak tersedia'), findsOneWidget);
  });

  testWidgets('ketuk thumbnail membuka pratinjau bukti', (tester) async {
    await seedBooking(fake, id: 'b1', status: 'pending');
    await fake.collection('bookings').doc('b1').update({
      'proofBase64': _png1x1,
    });
    await pumpVerify(tester);

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.text('Bukti transfer'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Verifikasi Pembayaran'), findsOneWidget);
  });

  testWidgets('terima booking mengubah status dan snackbar', (tester) async {
    await seedBooking(fake, id: 'b1', status: 'pending');
    await pumpVerify(tester);

    await tester.tap(find.text('Terima'));
    await tester.pumpAndSettle();
    expect(find.text('Terima booking?'), findsOneWidget);
    await tester.tap(find.text('Ya, terima'));
    await pollFor(tester, 'Booking disetujui.');

    expect(find.text('Booking disetujui.'), findsOneWidget);
    final doc = await fake.collection('bookings').doc('b1').get();
    expect(doc.data()?['status'], 'confirmed');
  });

  testWidgets('tolak booking mengubah status dan snackbar', (tester) async {
    await seedBooking(fake, id: 'b1', status: 'pending');
    await pumpVerify(tester);

    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    expect(find.text('Tolak booking?'), findsOneWidget);
    await tester.tap(find.text('Ya, tolak'));
    await pollFor(tester, 'Booking ditolak, slot kembali bebas.');

    expect(find.text('Booking ditolak, slot kembali bebas.'), findsOneWidget);
    final doc = await fake.collection('bookings').doc('b1').get();
    expect(doc.data()?['status'], 'rejected');
  });

  testWidgets('batal dialog tidak mengubah status', (tester) async {
    await seedBooking(fake, id: 'b1', status: 'pending');
    await pumpVerify(tester);

    await tester.tap(find.text('Terima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Terima booking?'), findsNothing);
    final doc = await fake.collection('bookings').doc('b1').get();
    expect(doc.data()?['status'], 'pending');
  });

  testWidgets('gagal memproses booking menampilkan snackbar error',
      (tester) async {
    await seedBooking(fake, id: 'b1', status: 'pending');
    await pumpVerify(tester);

    await tester.tap(find.text('Terima'));
    await tester.pumpAndSettle();
    await fake.collection('bookings').doc('b1').delete();
    await tester.tap(find.text('Ya, terima'));
    await pollFor(tester, 'Gagal memproses. Coba lagi.');

    expect(find.text('Gagal memproses. Coba lagi.'), findsOneWidget);
  });

  testWidgets('kartu seri membuka rincian dan terima seri', (tester) async {
    await seedSeriesWithMeetings();
    await pumpVerify(tester);

    expect(find.text('Langganan rutin'), findsOneWidget);
    expect(find.text('2 pertemuan'), findsOneWidget);
    expect(
      find.text('Lapangan 1 • setiap Sabtu 19:00–20:00'),
      findsOneWidget,
    );
    expect(find.text('Total: ${fmtRupiah(240000)}'), findsOneWidget);

    await openSeriesSheet(tester);
    expect(find.text('Daftar pertemuan'), findsOneWidget);
    expect(find.text('Terima seri'), findsOneWidget);
    expect(find.text('Tolak seri'), findsOneWidget);
    expect(find.text('Bukti tidak tersedia'), findsOneWidget);
    expect(
      find.textContaining(tanggalIndonesia(DateTime.parse('2026-11-21'))),
      findsOneWidget,
    );

    await tester.tap(find.text('Terima seri'));
    await tester.pumpAndSettle();
    expect(find.text('Terima seri langganan?'), findsOneWidget);
    await tester.tap(find.text('Ya, terima'));
    await pollFor(tester, 'Seri disetujui, semua pertemuan aktif.');

    expect(
      find.text('Seri disetujui, semua pertemuan aktif.'),
      findsOneWidget,
    );
    final s = await fake.collection('subscriptions').doc('s1').get();
    expect(s.data()?['status'], 'confirmed');
    final m1 = await fake.collection('bookings').doc('m1').get();
    expect(m1.data()?['status'], 'confirmed');
    final m2 = await fake.collection('bookings').doc('m2').get();
    expect(m2.data()?['status'], 'confirmed');
  });

  testWidgets('tolak seri mengubah status dan snackbar', (tester) async {
    await seedSeriesWithMeetings();
    await pumpVerify(tester);
    await openSeriesSheet(tester);

    await tester.tap(find.text('Tolak seri'));
    await tester.pumpAndSettle();
    expect(find.text('Tolak seri langganan?'), findsOneWidget);
    await tester.tap(find.text('Ya, tolak'));
    await pollFor(tester, 'Seri ditolak, semua slot kembali bebas.');

    expect(
      find.text('Seri ditolak, semua slot kembali bebas.'),
      findsOneWidget,
    );
    final s = await fake.collection('subscriptions').doc('s1').get();
    expect(s.data()?['status'], 'rejected');
  });

  testWidgets('batal dialog seri tidak mengubah status', (tester) async {
    await seedSeriesWithMeetings();
    await pumpVerify(tester);
    await openSeriesSheet(tester);

    await tester.tap(find.text('Terima seri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Terima seri langganan?'), findsNothing);
    final s = await fake.collection('subscriptions').doc('s1').get();
    expect(s.data()?['status'], 'pending');
  });

  testWidgets('dialog seri menyebut pertemuan yang tidak berubah',
      (tester) async {
    await seedSeriesWithMeetings(status2: 'cancelled');
    await pumpVerify(tester);
    await openSeriesSheet(tester);

    await tester.tap(find.text('Terima seri'));
    await tester.pumpAndSettle();

    expect(find.textContaining('tidak ikut berubah'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });

  testWidgets('rincian seri menampilkan bukti dan pratinjau',
      (tester) async {
    await seedSeriesWithMeetings();
    await fake.collection('subscriptions').doc('s1').update({
      'proofBase64': _png1x1,
    });
    await pumpVerify(tester);
    await openSeriesSheet(tester);

    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.text('Bukti transfer'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Daftar pertemuan'), findsOneWidget);
  });

  testWidgets('rincian seri bukti rusak menampilkan placeholder',
      (tester) async {
    await seedSeriesWithMeetings();
    await fake.collection('subscriptions').doc('s1').update({
      'proofBase64': '!!!bukan-base64!!!',
    });
    await pumpVerify(tester);
    await openSeriesSheet(tester);

    expect(find.text('Bukti tidak tersedia'), findsOneWidget);
  });

  testWidgets('seri tanpa pertemuan menampilkan pesan kosong',
      (tester) async {
    await seedSeries(fake);
    await pumpVerify(tester);
    await openSeriesSheet(tester);

    expect(find.text('Belum ada data pertemuan.'), findsOneWidget);
  });

  testWidgets('SeriesDetailScreen langsung terima seri', (tester) async {
    await seedSeriesWithMeetings();
    final doc = await fake.collection('subscriptions').doc('s1').get();
    final series = SubscriptionSeries.fromDoc(doc);
    await pumpDetail(tester, series);

    expect(find.text('Rincian Langganan'), findsOneWidget);
    expect(find.text('Daftar pertemuan'), findsOneWidget);

    await tester.tap(find.text('Terima seri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, terima'));
    await pollFor(tester, 'Seri disetujui, semua pertemuan aktif.');

    expect(
      find.text('Seri disetujui, semua pertemuan aktif.'),
      findsOneWidget,
    );
    final s = await fake.collection('subscriptions').doc('s1').get();
    expect(s.data()?['status'], 'confirmed');
  });

  testWidgets('SeriesDetailScreen langsung tolak seri', (tester) async {
    await seedSeriesWithMeetings();
    final doc = await fake.collection('subscriptions').doc('s1').get();
    final series = SubscriptionSeries.fromDoc(doc);
    await pumpDetail(tester, series);

    await tester.tap(find.text('Tolak seri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, tolak'));
    await pollFor(tester, 'Seri ditolak, semua slot kembali bebas.');

    expect(
      find.text('Seri ditolak, semua slot kembali bebas.'),
      findsOneWidget,
    );
    final s = await fake.collection('subscriptions').doc('s1').get();
    expect(s.data()?['status'], 'rejected');
  });

  testWidgets('SeriesDetailScreen gagal memproses menampilkan snackbar',
      (tester) async {
    await seedSeriesWithMeetings();
    final doc = await fake.collection('subscriptions').doc('s1').get();
    final series = SubscriptionSeries.fromDoc(doc);
    await pumpDetail(tester, series);

    await tester.tap(find.text('Terima seri'));
    await tester.pumpAndSettle();
    await fake.collection('subscriptions').doc('s1').delete();
    await tester.tap(find.text('Ya, terima'));
    await pollFor(tester, 'Gagal memproses. Coba lagi.');

    expect(find.text('Gagal memproses. Coba lagi.'), findsOneWidget);
  });

  testWidgets('gagal memproses seri menampilkan snackbar error',
      (tester) async {
    await seedSeriesWithMeetings();
    await pumpVerify(tester);
    await openSeriesSheet(tester);

    await tester.tap(find.text('Terima seri'));
    await tester.pumpAndSettle();
    await fake.collection('subscriptions').doc('s1').delete();
    await tester.tap(find.text('Ya, terima'));
    await pollFor(tester, 'Gagal memproses. Coba lagi.');

    expect(find.text('Gagal memproses. Coba lagi.'), findsOneWidget);
  });
}
