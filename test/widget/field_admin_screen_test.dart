import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/screens/field_admin_screen.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:deofoot/widgets/pitch_components.dart';
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

  Future<void> pumpAdmin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: FieldAdminScreen(firestoreService: fs())),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    Field? existing,
    Set<String> existingIds = const {},
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: FieldFormScreen(
          existing: existing,
          existingIds: existingIds,
          firestoreService: fs(),
        ),
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

  Future<void> isiForm(
    WidgetTester tester, {
    String nama = 'Lapangan Baru',
    String harga = '150000',
  }) async {
    await tester.enterText(find.byType(TextField).first, nama);
    await tester.enterText(find.byType(TextField).last, harga);
    await tester.pump();
  }

  testWidgets('tampil kosong tanpa lapangan', (tester) async {
    await pumpAdmin(tester);

    expect(find.text('Kelola Lapangan'), findsOneWidget);
    expect(
      find.text('Belum ada lapangan. Tambah lewat tombol +.'),
      findsOneWidget,
    );
    expect(find.text('Tambah'), findsOneWidget);
  });

  testWidgets('daftar menampilkan lapangan aktif', (tester) async {
    await seedField(fake);
    await pumpAdmin(tester);

    expect(find.text('Lapangan 1'), findsOneWidget);
    expect(find.text('Futsal • ${fmtRupiah(120000)}/jam'), findsOneWidget);
    expect(find.text('L1'), findsOneWidget);
    expect(find.textContaining('NONAKTIF'), findsNothing);
    expect(find.byType(PitchToggle), findsOneWidget);
  });

  testWidgets('lapangan nonaktif ditandai NONAKTIF', (tester) async {
    await seedField(fake, isActive: false);
    await pumpAdmin(tester);

    expect(
      find.text('Futsal • ${fmtRupiah(120000)}/jam • NONAKTIF'),
      findsOneWidget,
    );
  });

  testWidgets('saklar menonaktifkan lapangan', (tester) async {
    await seedField(fake);
    await pumpAdmin(tester);

    await tester.tap(find.byType(PitchToggle));
    await pollFor(
      tester,
      'Lapangan 1 dinonaktifkan (disembunyikan dari user).',
    );

    expect(
      find.text('Lapangan 1 dinonaktifkan (disembunyikan dari user).'),
      findsOneWidget,
    );
    final doc = await fake.collection('fields').doc('l1').get();
    expect(doc.data()?['isActive'], isFalse);
  });

  testWidgets('saklar mengaktifkan lapangan', (tester) async {
    await seedField(fake, isActive: false);
    await pumpAdmin(tester);

    await tester.tap(find.byType(PitchToggle));
    await pollFor(tester, 'Lapangan 1 diaktifkan.');

    expect(find.text('Lapangan 1 diaktifkan.'), findsOneWidget);
    final doc = await fake.collection('fields').doc('l1').get();
    expect(doc.data()?['isActive'], isTrue);
  });

  testWidgets('gagal mengubah status menampilkan snackbar error',
      (tester) async {
    await seedField(fake);
    await pumpAdmin(tester);
    await fake.collection('fields').doc('l1').delete();

    await tester.tap(find.byType(PitchToggle));
    await pollFor(tester, 'Gagal mengubah status. Coba lagi.');

    expect(find.text('Gagal mengubah status. Coba lagi.'), findsOneWidget);
  });

  testWidgets('ketuk kartu membuka form ubah terisi', (tester) async {
    await seedField(fake);
    await pumpAdmin(tester);

    await tester.tap(find.text('Lapangan 1'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Lapangan'), findsOneWidget);
    final namaField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(namaField.controller?.text, 'Lapangan 1');
    final hargaField = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(hargaField.controller?.text, '120000');
  });

  testWidgets('FAB membuka form tambah kosong', (tester) async {
    await seedField(fake);
    await pumpAdmin(tester);

    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Lapangan'), findsOneWidget);
    expect(find.text('Nama lapangan'), findsOneWidget);
    expect(find.text('Harga per jam (Rp)'), findsOneWidget);
    expect(find.text('Futsal'), findsOneWidget);
    expect(find.text('Navy'), findsOneWidget);
    expect(find.text('Lapangan aktif'), findsOneWidget);
  });

  testWidgets('tambah lapangan baru menyimpan dan snackbar', (tester) async {
    await seedField(fake);
    await pumpAdmin(tester);
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    await isiForm(tester);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Padel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oranye'));
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    // Biarkan pop selesai: pompa pertama menjalankan microtask pop +
    // SnackBar (pop baru dimulai sesudah frame tap), pompa kedua
    // memajukan animasi pop 300ms sampai rute form terlepas. Selama
    // form masih animasi keluar, SnackBar tampil di DUA Scaffold dan
    // teks form masih ada di tree.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await pollFor(tester, 'Lapangan ditambahkan.');

    expect(find.text('Lapangan ditambahkan.'), findsOneWidget);
    expect(find.text('Lapangan Baru'), findsOneWidget);
    final doc =
        await fake.collection('fields').doc('lapangan-baru').get();
    expect(doc.data()?['name'], 'Lapangan Baru');
    expect(doc.data()?['pricePerHour'], 150000);
    expect(doc.data()?['category'], 'Padel');
    expect(doc.data()?['color'], 0xFFFF7A1A);
    expect(doc.data()?['isActive'], isTrue);
  });

  testWidgets('ubah lapangan menyimpan perubahan', (tester) async {
    await seedField(fake);
    await pumpAdmin(tester);
    await tester.tap(find.text('Lapangan 1'));
    await tester.pumpAndSettle();

    await isiForm(tester, nama: 'Lapangan 1A', harga: '200000');
    await tester.tap(find.text('Simpan'));
    // Biarkan pop selesai (lihat catatan di test tambah).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await pollFor(tester, 'Lapangan disimpan.');

    expect(find.text('Lapangan disimpan.'), findsOneWidget);
    final doc = await fake.collection('fields').doc('l1').get();
    expect(doc.data()?['name'], 'Lapangan 1A');
    expect(doc.data()?['pricePerHour'], 200000);
  });

  testWidgets('validasi nama kosong menampilkan snackbar', (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextField).last, '150000');
    await tester.tap(find.text('Simpan'));
    await pollFor(tester, 'Nama lapangan wajib diisi.');

    expect(find.text('Nama lapangan wajib diisi.'), findsOneWidget);
    expect(find.text('Tambah Lapangan'), findsOneWidget);
  });

  testWidgets('validasi harga nol menampilkan snackbar', (tester) async {
    await pumpForm(tester);

    await isiForm(tester, harga: '0');
    await tester.tap(find.text('Simpan'));
    await pollFor(tester, 'Harga per jam harus angka lebih dari 0.');

    expect(
      find.text('Harga per jam harus angka lebih dari 0.'),
      findsOneWidget,
    );
  });

  testWidgets('form nonaktifkan lapangan lalu simpan', (tester) async {
    await pumpForm(tester);

    await isiForm(tester);
    await tester.tap(find.byType(PitchToggle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await pollFor(tester, 'Lapangan ditambahkan.');

    final doc =
        await fake.collection('fields').doc('lapangan-baru').get();
    expect(doc.data()?['isActive'], isFalse);
  });

  testWidgets('gagal menyimpan menampilkan snackbar error', (tester) async {
    await seedField(fake);
    final doc = await fake.collection('fields').doc('l1').get();
    final existing = Field.fromDoc(doc);
    await pumpForm(tester, existing: existing, existingIds: {'l1'});
    await fake.collection('fields').doc('l1').delete();

    await isiForm(tester, nama: 'Lapangan 1A', harga: '200000');
    await tester.tap(find.text('Simpan'));
    await pollFor(tester, 'Gagal menyimpan. Coba lagi.');

    expect(find.text('Gagal menyimpan. Coba lagi.'), findsOneWidget);
    expect(find.text('Ubah Lapangan'), findsOneWidget);
  });

  testWidgets('chip warna berubah lalu tersimpan', (tester) async {
    await pumpForm(tester);

    await isiForm(tester);
    await tester.tap(find.text('Biru'));
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await pollFor(tester, 'Lapangan ditambahkan.');

    final doc =
        await fake.collection('fields').doc('lapangan-baru').get();
    expect(doc.data()?['color'], 0xFF2563EB);
  });
}
