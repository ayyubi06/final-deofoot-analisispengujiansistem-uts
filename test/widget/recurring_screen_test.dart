import 'dart:convert';
import 'dart:io';

import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/recurring_logic.dart';
import 'package:deofoot/report_logic.dart';
import 'package:deofoot/screens/recurring_screen.dart';
import 'package:deofoot/services/auth_service.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:deofoot/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fase2_helpers.dart';

// PNG 1x1 transparan untuk berkas bukti palsu.
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC';

/// Platform image_picker palsu: getImageFromSource mengembalikan berkas
/// yang disetel test (atau null bila pengguna batal memilih).
class FakeImagePicker extends ImagePickerPlatform {
  XFile? fileToReturn;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => fileToReturn;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fake;
  late MockPlugin plugin;
  late FakeImagePicker fakePicker;
  late ImagePickerPlatform originalPicker;
  late Directory proofDir;
  late String proofPath;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    originalPicker = ImagePickerPlatform.instance;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    plugin = MockPlugin();
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(() => plugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    fakePicker = FakeImagePicker();
    proofDir = await Directory.systemTemp.createTemp('deofoot-proof');
    proofPath = '${proofDir.path}/bukti.png';
    await File(proofPath).writeAsBytes(base64Decode(_png1x1));
    fakePicker.fileToReturn = XFile(proofPath);
    ImagePickerPlatform.instance = fakePicker;
  });

  tearDown(() async {
    ImagePickerPlatform.instance = originalPicker;
    if (await proofDir.exists()) {
      await proofDir.delete(recursive: true);
    }
  });

  Future<void> pumpRecurring(
    WidgetTester tester, {
    DateTime? initialDate,
    int? initialStartHour,
    int? initialDuration,
    bool signedIn = true,
  }) async {
    // Viewport tinggi supaya seluruh isi scroll ikut dibangun.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = signedIn
        ? MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'u1', email: 'u1@test.com'),
          )
        : MockFirebaseAuth();
    final fs = FirestoreService(db: fake);
    await tester.pumpWidget(
      MaterialApp(
        home: RecurringScreen(
          field: Field(id: 'l1', name: 'Lapangan 1', pricePerHour: 120000),
          initialDate: initialDate,
          initialStartHour: initialStartHour,
          initialDuration: initialDuration,
          firestoreService: fs,
          authService: AuthService(auth: auth),
          notificationService: NotificationService.forTest(
            plugin: plugin,
            firestoreService: fs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickProof(
    WidgetTester tester, {
    String via = 'Pilih dari galeri',
  }) async {
    await tester.tap(find.text('Pilih bukti transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(via));
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

  /// Ketuk Kirim + tunggu sampai teks muncul. Ketukan HARUS di dalam
  /// runAsync: _send membaca berkas bukti via File.readAsBytes (IO
  /// sungguhan) yang tidak pernah selesai bila dimulai di zona FakeAsync
  /// test (terbukti via probe_io_test: tulis/baca dart:io menggantung
  /// di badan testWidgets; setUp berjalan di zona asli sehingga aman).
  /// Di dalam runAsync, _send berjalan di zona asli dan IO selesai.
  Future<void> tapSendAndWait(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Kirim Langganan'));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await pollFor(tester, text);
  }

  testWidgets('tampil form langganan lengkap', (tester) async {
    await seedPaymentConfig(fake);
    await pumpRecurring(tester);

    expect(find.text('Langganan Rutin'), findsOneWidget);
    expect(find.text('Atur seri mingguan'), findsOneWidget);
    expect(find.text('Lapangan 1'), findsOneWidget);
    expect(find.text('Hari'), findsOneWidget);
    expect(find.text('Pertemuan pertama'), findsOneWidget);
    expect(find.text('Jam mulai'), findsOneWidget);
    expect(find.text('Durasi'), findsOneWidget);
    expect(find.text('Pertemuan'), findsOneWidget);
    expect(find.text('4×'), findsOneWidget);
    expect(find.text('8×'), findsOneWidget);
    expect(find.text('12×'), findsOneWidget);
    expect(find.text('Nomor WhatsApp'), findsOneWidget);
    expect(find.text('Nomor WhatsApp aktif'), findsOneWidget);
    expect(
      find.text('Pembayaran (satu kali untuk seluruh seri)'),
      findsOneWidget,
    );
    expect(find.text('Nomor DANA: 081234567890'), findsOneWidget);
    expect(find.text('a.n. Deofoot'), findsOneWidget);
    expect(find.text('Salin nomor'), findsOneWidget);
    expect(find.text('Bukti transfer'), findsOneWidget);
    expect(find.text('Belum ada bukti transfer'), findsOneWidget);
    expect(find.text('Pilih bukti transfer'), findsOneWidget);
    expect(find.text('Kirim Langganan'), findsOneWidget);
    expect(
      find.text('Pilih bukti transfer dulu untuk mengaktifkan tombol.'),
      findsOneWidget,
    );
    // Tanggal pertama seri = besok (hari bawaan = hari besok).
    final besok = DateTime.now().add(const Duration(days: 1));
    expect(find.text(fmtDate(besok)), findsOneWidget);
  });

  testWidgets('tanpa config pembayaran menampilkan strip', (tester) async {
    await pumpRecurring(tester);

    // getPaymentConfig mengembalikan '-' bila dokumen tidak ada
    // (bukan null — jadi fallback '...' hanya tampil sesaat saat loading).
    expect(find.text('Nomor DANA: -'), findsOneWidget);
    expect(find.text('a.n. -'), findsOneWidget);
  });

  testWidgets('ganti hari mengubah pertemuan pertama', (tester) async {
    await pumpRecurring(tester);

    await tester.tap(find.text('Rabu'));
    await tester.pumpAndSettle();

    final expected = tanggalPertamaUntukHari(3, DateTime.now());
    expect(find.text(tanggalIndonesia(expected)), findsOneWidget);
  });

  testWidgets('ganti jam dan durasi', (tester) async {
    await pumpRecurring(tester);

    await tester.tap(find.byType(DropdownButton<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('19.00').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('19.00'), findsNWidgets(2));

    await tester.tap(find.byType(DropdownButton<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 jam'));
    await tester.pumpAndSettle();
    expect(find.text('2 jam'), findsOneWidget);
  });

  testWidgets('ganti jumlah pertemuan mengubah daftar tanggal',
      (tester) async {
    await pumpRecurring(tester);

    await tester.tap(find.text('8×'));
    await tester.pumpAndSettle();

    expect(find.text('Total (8 pertemuan)'), findsOneWidget);
    final besok = DateTime.now().add(const Duration(days: 1));
    expect(
      find.text(fmtDate(besok.add(const Duration(days: 49)))),
      findsOneWidget,
    );
  });

  testWidgets('salin nomor DANA menampilkan snackbar', (tester) async {
    await seedPaymentConfig(fake);
    await pumpRecurring(tester);

    await tester.tap(find.text('Salin nomor'));
    await pollFor(tester, 'Nomor DANA disalin.');

    expect(find.text('Nomor DANA disalin.'), findsOneWidget);
  });

  testWidgets('pilih bukti dari galeri menampilkan pratinjau',
      (tester) async {
    await pumpRecurring(tester);
    await pickProof(tester, via: 'Pilih dari galeri');

    expect(find.text('Ganti bukti transfer'), findsOneWidget);
    expect(find.text('Belum ada bukti transfer'), findsNothing);
    expect(
      find.text('Pilih bukti transfer dulu untuk mengaktifkan tombol.'),
      findsNothing,
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('pilih bukti dari kamera menampilkan pratinjau',
      (tester) async {
    await pumpRecurring(tester);
    await pickProof(tester, via: 'Ambil foto');

    expect(find.text('Ganti bukti transfer'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('batal pilih bukti tidak mengubah apa pun', (tester) async {
    fakePicker.fileToReturn = null;
    await pumpRecurring(tester);
    await pickProof(tester, via: 'Pilih dari galeri');

    expect(find.text('Belum ada bukti transfer'), findsOneWidget);
    expect(find.text('Pilih bukti transfer'), findsOneWidget);
  });

  testWidgets('kirim langganan sukses membuat seri', (tester) async {
    await pumpRecurring(tester);
    await tester.enterText(
      find.byType(TextFormField),
      '081234567890',
    );
    await tester.pumpAndSettle();
    await pickProof(tester);

    // Indikator 'Mengirim…' (indeterminate) tidak bisa diamati dari test:
    // _send harus berjalan di runAsync agar IO berkas selesai, dan saat
    // runAsync kembali _send sudah selesai. Baris indikator tetap tak
    // tertutup — diterima (UI sesaat).
    await tapSendAndWait(tester, 'Langganan terkirim, menunggu verifikasi.');

    expect(
      find.text('Langganan terkirim, menunggu verifikasi.'),
      findsOneWidget,
    );
    final subs = await fake.collection('subscriptions').get();
    expect(subs.docs, hasLength(1));
    final bookings = await fake.collection('bookings').get();
    expect(bookings.docs, hasLength(4));
  });

  testWidgets('kirim dengan WA tidak valid menampilkan error validasi',
      (tester) async {
    await pumpRecurring(tester);
    await tester.enterText(find.byType(TextFormField), '123');
    await tester.pumpAndSettle();
    await pickProof(tester);

    await tester.tap(find.text('Kirim Langganan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nomor WA wajib diisi, format 08… (10–14 digit).'),
      findsOneWidget,
    );
    final subs = await fake.collection('subscriptions').get();
    expect(subs.docs, isEmpty);
  });

  testWidgets('kirim tanpa login menampilkan snackbar gagal',
      (tester) async {
    await pumpRecurring(tester, signedIn: false);
    await tester.enterText(
      find.byType(TextFormField),
      '081234567890',
    );
    await tester.pumpAndSettle();
    await pickProof(tester);

    await tapSendAndWait(
      tester,
      'Gagal mengirim langganan. Periksa koneksi lalu coba lagi.',
    );

    expect(
      find.text('Gagal mengirim langganan. Periksa koneksi lalu coba lagi.'),
      findsOneWidget,
    );
  });

  testWidgets('slot bentrok menampilkan dialog konflik', (tester) async {
    final besok = DateTime.now().add(const Duration(days: 1));
    await seedBooking(
      fake,
      id: 'bentrok',
      fieldId: 'l1',
      date: fmtDate(besok),
      startTime: '08:00',
      endTime: '09:00',
      status: 'confirmed',
    );
    await pumpRecurring(tester, initialDate: besok);
    await tester.enterText(
      find.byType(TextFormField),
      '081234567890',
    );
    await tester.pumpAndSettle();
    await pickProof(tester);

    // Jangan pumpAndSettle selagi _sending: indikator progresnya
    // indeterminate (tanpa value) sehingga settle tidak pernah selesai.
    await tapSendAndWait(tester, 'Slot sudah terisi');

    expect(find.text('Slot sudah terisi'), findsOneWidget);
    expect(find.text('Mengerti'), findsOneWidget);
    await tester.tap(find.text('Mengerti'));
    // Pompa pendek sampai dialog hilang (pumpAndSettle tidak bisa dipakai:
    // indikator indeterminate masih beranimasi selagi _sending true,
    // dan _sending baru false sesudah dialog tertutup penuh).
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Slot sudah terisi').evaluate().isEmpty) break;
    }
    expect(find.text('Slot sudah terisi'), findsNothing);
  });

  testWidgets('durasi dijepit saat jam mulai mendekati tutup',
      (tester) async {
    await pumpRecurring(
      tester,
      initialStartHour: 21,
      initialDuration: 4,
    );

    expect(find.text('1 jam'), findsOneWidget);
  });

  testWidgets('jam mulai di luar jam buka dijepit ke jam buka',
      (tester) async {
    await pumpRecurring(tester, initialStartHour: 23);

    expect(find.text('08.00'), findsOneWidget);
  });

  testWidgets('tanggal awal menentukan hari seri', (tester) async {
    final rabu = tanggalPertamaUntukHari(3, DateTime.now());
    await pumpRecurring(tester, initialDate: rabu);

    expect(find.text(tanggalIndonesia(rabu)), findsOneWidget);
  });
}
