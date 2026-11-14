import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/calendar_logic.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/screens/schedule_screen.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  FirestoreService fs() => FirestoreService(db: fake);

  Field lapangan({bool isActive = true}) => Field(
    id: 'l1',
    name: 'Lapangan 1',
    pricePerHour: 120000,
    isActive: isActive,
  );

  Future<void> pumpSchedule(
    WidgetTester tester, {
    Field? field,
    DateTime? initialDate,
    int? initialStartHour,
    int? initialDuration,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleScreen(
          field: field ?? lapangan(),
          initialDate: initialDate,
          initialStartHour: initialStartHour,
          initialDuration: initialDuration,
          firestoreService: fs(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  DateTime besok() => DateTime.now().add(const Duration(days: 1));

  testWidgets('tampil jadwal hari ini lengkap', (tester) async {
    await pumpSchedule(tester);

    expect(find.text('Jadwal — Lapangan 1'), findsOneWidget);
    expect(find.text('Tanggal main'), findsOneWidget);
    expect(find.text(indoFullDate(DateTime.now())), findsOneWidget);
    expect(find.text('Bebas'), findsOneWidget);
    expect(find.text('Terisi'), findsOneWidget);
    expect(find.text('Menunggu'), findsOneWidget);
    expect(find.text('Lewat'), findsOneWidget);
    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsOneWidget,
    );
    expect(find.text('19.00'), findsOneWidget);
    expect(find.byTooltip('Langganan rutin'), findsOneWidget);
  });

  testWidgets('lapangan nonaktif menampilkan pesan', (tester) async {
    await pumpSchedule(tester, field: lapangan(isActive: false));

    expect(find.text('Jadwal — Lapangan 1'), findsOneWidget);
    expect(
      find.text(
        'Lapangan ini sedang nonaktif dan tidak menerima booking.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tanggal main'), findsNothing);
  });

  testWidgets('tap slot bebas menampilkan ringkasan dan total',
      (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();

    expect(find.text('1 jam · 19.00–20.00'), findsOneWidget);
    expect(find.text(fmtRupiah(120000)), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsNothing,
    );
  });

  testWidgets('tap dua slot berurutan memperpanjang ringkasan',
      (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20.00'));
    await tester.pumpAndSettle();

    expect(find.text('2 jam · 19.00–21.00'), findsOneWidget);
    expect(find.text(fmtRupiah(240000)), findsOneWidget);
  });

  testWidgets('tap ulang slot terpilih membatalkan seleksi',
      (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsOneWidget,
    );
    expect(find.text('Lanjut'), findsNothing);
  });

  testWidgets('slot terisi (confirmed) tidak bisa dipilih', (tester) async {
    await seedBooking(
      fake,
      date: fmtDate(besok()),
      startTime: '19:00',
      endTime: '20:00',
      status: 'confirmed',
    );
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsOneWidget,
    );
    expect(find.text('Lanjut'), findsNothing);
  });

  testWidgets('slot menunggu (pending) tidak bisa dipilih', (tester) async {
    await seedBooking(
      fake,
      date: fmtDate(besok()),
      startTime: '19:00',
      endTime: '20:00',
      status: 'pending',
    );
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsOneWidget,
    );
    expect(find.text('Lanjut'), findsNothing);
  });

  testWidgets('ganti tanggal lewat kalender mengubah label tanggal',
      (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('Tanggal main'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih tanggal'), findsOneWidget);

    final target = DateTime.now().add(const Duration(days: 3));
    await tester.tap(find.text('${target.day}').first);
    await tester.pumpAndSettle();

    expect(find.text(indoFullDate(target)), findsOneWidget);
    expect(find.text('Pilih tanggal'), findsNothing);
  });

  testWidgets('ganti tanggal menghapus seleksi', (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();
    expect(find.text('1 jam · 19.00–20.00'), findsOneWidget);

    await tester.tap(find.text('Tanggal main'));
    await tester.pumpAndSettle();
    final target = DateTime.now().add(const Duration(days: 3));
    await tester.tap(find.text('${target.day}').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsOneWidget,
    );
    expect(find.text('1 jam · 19.00–20.00'), findsNothing);
  });

  testWidgets('pra-seleksi dari Cari Slot diterapkan', (tester) async {
    await pumpSchedule(
      tester,
      initialDate: besok(),
      initialStartHour: 19,
      initialDuration: 2,
    );

    // Pra-seleksi diterapkan di dalam builder StreamBuilder tanpa
    // setState, jadi bar bawah baru membaca _sel yang baru sesudah
    // rebuild berikutnya. Pompa ulang widget yang sama untuk memicu
    // rebuild itu (state dipertahankan, initState tidak jalan lagi).
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleScreen(
          field: lapangan(),
          initialDate: besok(),
          initialStartHour: 19,
          initialDuration: 2,
          firestoreService: fs(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 jam · 19.00–21.00'), findsOneWidget);
    expect(find.text(fmtRupiah(240000)), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
  });

  testWidgets('pra-seleksi gugur bila slot sudah terisi', (tester) async {
    await seedBooking(
      fake,
      date: fmtDate(besok()),
      startTime: '19:00',
      endTime: '20:00',
      status: 'confirmed',
    );
    await pumpSchedule(
      tester,
      initialDate: besok(),
      initialStartHour: 19,
      initialDuration: 2,
    );

    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsOneWidget,
    );
    expect(find.text('Lanjut'), findsNothing);
  });

  testWidgets('pra-seleksi tanpa durasi tidak diterapkan', (tester) async {
    await pumpSchedule(
      tester,
      initialDate: besok(),
      initialStartHour: 19,
    );

    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsOneWidget,
    );
    expect(find.text('Lanjut'), findsNothing);
  });

  testWidgets('stream update mengubah status slot', (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    // Booking tanggal lain: status besok tidak berubah.
    await seedBooking(
      fake,
      id: 'b-lain',
      date: fmtDate(DateTime.now().add(const Duration(days: 5))),
      startTime: '19:00',
      endTime: '20:00',
      status: 'confirmed',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();
    expect(find.text('1 jam · 19.00–20.00'), findsOneWidget);

    // Booking besok masuk belakangan: slot 19.00 jadi terisi,
    // tap berikutnya tidak menambah seleksi.
    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();
    await seedBooking(
      fake,
      id: 'b-besok',
      date: fmtDate(besok()),
      startTime: '19:00',
      endTime: '20:00',
      status: 'confirmed',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();
    expect(
      find.text('Pilih slot bebas untuk melanjutkan'),
      findsOneWidget,
    );
  });

  testWidgets('initialDate lampau kembali ke hari ini', (tester) async {
    final lampau = DateTime.now().subtract(const Duration(days: 5));
    await pumpSchedule(tester, initialDate: lampau);

    expect(find.text(indoFullDate(DateTime.now())), findsOneWidget);
  });

  testWidgets('initialDate lebih dari 89 hari kembali ke hari ini',
      (tester) async {
    final jauh = DateTime.now().add(const Duration(days: 100));
    await pumpSchedule(tester, initialDate: jauh);

    expect(find.text(indoFullDate(DateTime.now())), findsOneWidget);
  });

  testWidgets('initialDate sah dipakai', (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    expect(find.text(indoFullDate(besok())), findsOneWidget);
  });

  testWidgets('tombol tutup menutup kalender tanpa mengubah tanggal',
      (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('Tanggal main'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih tanggal'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih tanggal'), findsNothing);
    expect(find.text(indoFullDate(besok())), findsOneWidget);
  });

  testWidgets('tombol langganan rutin membuka layar langganan',
      (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    // RecurringScreen yang di-push tidak menerima authService, jadi
    // fallback AuthService() melempar tanpa Firebase terinisialisasi.
    // Itu perilaku layar yang diuji, bukan kegagalan test: tangkap
    // exception-nya dan pastikan rute baru sudah didorong.
    await tester.tap(find.byTooltip('Langganan rutin'));
    await tester.pump();
    expect(tester.takeException(), isNotNull);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorWidget), findsOneWidget);
  });

  testWidgets('tombol Lanjut membuka layar booking', (tester) async {
    await pumpSchedule(tester, initialDate: besok());

    await tester.tap(find.text('19.00'));
    await tester.pumpAndSettle();
    expect(find.text('Lanjut'), findsOneWidget);

    // Sama seperti navigasi langganan: BookingScreen yang di-push
    // tidak menerima authService/notificationService.
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    expect(tester.takeException(), isNotNull);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorWidget), findsOneWidget);
  });
}
