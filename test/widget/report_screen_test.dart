import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/screens/report_screen.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fase2_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeFirebaseFirestore fake;

  setUp(() {
    fake = FakeFirebaseFirestore();
  });

  Future<void> pumpReport(WidgetTester tester) async {
    // Viewport tinggi supaya seluruh isi ListView ikut dibangun
    // (ListView malas: widget di bawah lipatan tidak ada di tree).
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(
          firestoreService: FirestoreService(db: fake),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickDay(
    WidgetTester tester,
    String day, {
    String confirm = 'OK',
  }) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.pump();
    await tester.tap(find.text(confirm));
    await tester.pumpAndSettle();
  }

  testWidgets('tampil ringkasan kosong tanpa booking', (tester) async {
    await pumpReport(tester);

    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('7 hari terakhir'), findsOneWidget);
    expect(find.text('Bulan ini'), findsOneWidget);
    expect(find.text('Pilih tanggal'), findsOneWidget);
    expect(find.text('Jumlah per Status'), findsOneWidget);
    expect(find.text('Per Lapangan'), findsOneWidget);
    expect(
      find.text('Tidak ada booking Disetujui pada periode ini.'),
      findsOneWidget,
    );
    expect(find.text('Per Tanggal'), findsOneWidget);
    expect(find.text('Tidak ada data.'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(
      find.text('Pendapatan hanya dari booking Disetujui.'),
      findsOneWidget,
    );
  });

  testWidgets('tampil agregat dengan booking Disetujui', (tester) async {
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
      status: 'confirmed',
      date: today,
      startTime: '20:00',
      endTime: '21:00',
    );
    await pumpReport(tester);

    expect(find.text('Lapangan 1'), findsOneWidget);
    expect(find.text('2 booking'), findsOneWidget);
    expect(
      find.text('Tidak ada booking Disetujui pada periode ini.'),
      findsNothing,
    );
    expect(find.text('Tidak ada data.'), findsNothing);
  });

  testWidgets('ganti rentang mengubah periode', (tester) async {
    final today = DateTime.now();
    await seedBooking(
      fake,
      id: 'b1',
      status: 'confirmed',
      date: fmtDate(today),
    );
    await seedBooking(
      fake,
      id: 'b2',
      status: 'confirmed',
      date: fmtDate(today.subtract(const Duration(days: 3))),
    );
    await pumpReport(tester);

    expect(find.text('1 booking'), findsOneWidget);

    await tester.tap(find.text('7 hari terakhir'));
    await tester.pumpAndSettle();
    expect(find.text('1 booking'), findsNWidgets(2));

    await tester.tap(find.text('Bulan ini'));
    await tester.pumpAndSettle();
    expect(find.text('1 booking'), findsNWidgets(2));

    await tester.tap(find.text('Hari ini'));
    await tester.pumpAndSettle();
    expect(find.text('1 booking'), findsOneWidget);
  });

  testWidgets('pilih tanggal menampilkan pemilih dan memilih tanggal',
      (tester) async {
    await pumpReport(tester);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dari:'), findsOneWidget);
    expect(find.textContaining('Sampai:'), findsOneWidget);

    await tester.tap(find.textContaining('Dari:'));
    await pickDay(tester, '20');
    final now = DateTime.now();
    expect(
      find.text('Dari: ${fmtDate(DateTime(now.year, now.month, 20))}'),
      findsOneWidget,
    );
  });

  testWidgets('batal pilih tanggal tidak mengubah rentang', (tester) async {
    await pumpReport(tester);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Dari:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsNothing);
    expect(
      find.text('Dari: ${fmtDate(DateTime.now())}'),
      findsOneWidget,
    );
  });

  testWidgets('tanggal akhir menyesuaikan saat awal melewatinya',
      (tester) async {
    await pumpReport(tester);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Sampai:'));
    await pickDay(tester, '10');
    final now = DateTime.now();
    final tgl10 = fmtDate(DateTime(now.year, now.month, 10));
    final tgl20 = fmtDate(DateTime(now.year, now.month, 20));
    expect(find.text('Sampai: $tgl10'), findsOneWidget);

    await tester.tap(find.textContaining('Dari:'));
    await pickDay(tester, '20');
    expect(find.text('Dari: $tgl20'), findsOneWidget);
    expect(find.text('Sampai: $tgl20'), findsOneWidget);
  });

  testWidgets('tanggal awal menyesuaikan saat akhir mendahuluinya',
      (tester) async {
    await pumpReport(tester);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Dari:'));
    await pickDay(tester, '20');
    final now = DateTime.now();
    final tgl10 = fmtDate(DateTime(now.year, now.month, 10));
    final tgl20 = fmtDate(DateTime(now.year, now.month, 20));
    expect(find.text('Dari: $tgl20'), findsOneWidget);

    await tester.tap(find.textContaining('Sampai:'));
    await pickDay(tester, '10');
    expect(find.text('Sampai: $tgl10'), findsOneWidget);
    expect(find.text('Dari: $tgl10'), findsOneWidget);
  });

  testWidgets('export PDF sukses tanpa snackbar gagal', (tester) async {
    const channel = MethodChannel('net.nfet.printing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 1);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await seedBooking(
      fake,
      id: 'b1',
      status: 'confirmed',
      date: fmtDate(DateTime.now()),
    );
    await pumpReport(tester);

    await tester.ensureVisible(find.text('Export PDF'));
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal membuat PDF. Coba lagi.'), findsNothing);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('export PDF gagal menampilkan snackbar', (tester) async {
    // Channel printing dimock MELEMPAR: tanpa mock, panggilan channel di
    // test menggantung selamanya (terbukti via PROBE: tombol macet di
    // 'Membuat PDF…'), bukan melempar MissingPluginException.
    const channel = MethodChannel('net.nfet.printing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await pumpReport(tester);

    await tester.ensureVisible(find.text('Export PDF'));
    await tester.tap(find.text('Export PDF'));
    // Jangan pumpAndSettle: SnackBar hilang sendiri setelah 4 detik.
    // Pompa pendek berulang sampai SnackBar muncul (maks 4 detik).
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Gagal membuat PDF. Coba lagi.').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Gagal membuat PDF. Coba lagi.'), findsOneWidget);
  });
}
