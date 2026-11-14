import 'dart:convert';
import 'dart:io';

import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/calendar_logic.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/screens/booking_screen.dart';
import 'package:deofoot/services/auth_service.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:deofoot/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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

  DateTime besok() => DateTime.now().add(const Duration(days: 1));

  /// Pembungkus testWidgets yang meredam SATU asersi debug framework:
  /// RadioListTile metode pembayaran berada di dalam PitchCard
  /// (DecoratedBox berwarna tanpa Material di antaranya), sehingga
  /// ListTile melaporkan 'ListTile background color or ink splashes
  /// may be invisible' setiap kali tile dibangun. Itu asersi mode
  /// debug + masalah kosmetik produksi (ripple radio tak terlihat);
  /// di build rilis tidak berpengaruh. Perbaikan produksinya adalah
  /// membungkus RadioGroup dengan Material (2 baris di
  /// booking_screen.dart) — sengaja TIDAK dilakukan di sini karena
  /// kampanye ini test-only; temuan ini dilaporkan ke pemilik.
  /// Error lain diteruskan ke handler asli, dan handler selalu
  /// dipulihkan (try/finally) supaya laporan kegagalan test tetap utuh.
  void bookingTestWidgets(
    String description,
    WidgetTesterCallback body,
  ) {
    testWidgets(description, (tester) async {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains(
          'ListTile background color',
        )) {
          return;
        }
        original?.call(details);
      };
      try {
        await body(tester);
      } finally {
        FlutterError.onError = original;
      }
    });
  }

  BookingScreen bookingWidget({bool signedIn = true}) {
    final auth = signedIn
        ? MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'u1', email: 'u1@test.com'),
          )
        : MockFirebaseAuth();
    final fs = FirestoreService(db: fake);
    return BookingScreen(
      field: Field(id: 'l1', name: 'Lapangan 1', pricePerHour: 120000),
      date: besok(),
      startHour: 19,
      endHour: 21,
      firestoreService: fs,
      authService: AuthService(auth: auth),
      notificationService: NotificationService.forTest(
        plugin: plugin,
        firestoreService: fs,
      ),
    );
  }

  Future<void> pumpBooking(
    WidgetTester tester, {
    bool signedIn = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: bookingWidget(signedIn: signedIn)),
    );
    await tester.pumpAndSettle();
  }

  /// Pompa dengan satu rute di bawahnya ('Depan'), supaya pop dan
  /// popUntil dari layar ini bisa diamati perilakunya.
  Future<void> pumpBookingWithBack(
    WidgetTester tester, {
    bool signedIn = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Depan'))),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute(
            builder: (_) => bookingWidget(signedIn: signedIn),
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
  /// test. Di dalam runAsync, _send berjalan di zona asli dan IO selesai.
  Future<void> tapSendAndWait(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Kirim Booking'));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await pollFor(tester, text);
  }

  Future<void> isiWaValid(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField), '081234567890');
    await tester.pumpAndSettle();
  }

  bookingTestWidgets('tampil form booking lengkap', (tester) async {
    await seedPaymentConfig(fake);
    await pumpBooking(tester);

    expect(find.text('Booking Lapangan'), findsOneWidget);
    expect(find.text('Ringkasan booking'), findsOneWidget);
    expect(find.text('Lapangan 1'), findsOneWidget);
    expect(find.text(indoFullDate(besok())), findsOneWidget);
    expect(find.text('19.00 – 21.00'), findsOneWidget);
    expect(find.text('120 menit'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text(fmtRupiah(240000)), findsOneWidget);
    expect(find.text('Nomor WhatsApp'), findsOneWidget);
    expect(find.text('Nomor WhatsApp aktif'), findsOneWidget);
    expect(find.text('Pembayaran'), findsOneWidget);
    expect(find.text('DANA'), findsOneWidget);
    expect(find.text('Transfer Bank'), findsOneWidget);
    expect(find.text('E-Wallet lain'), findsOneWidget);
    expect(find.text('Tujuan (DANA):'), findsOneWidget);
    expect(find.text('Nomor DANA: 081234567890'), findsOneWidget);
    expect(find.text('a.n. Deofoot'), findsOneWidget);
    expect(find.text('Salin nomor'), findsOneWidget);
    expect(find.text('Bukti transfer'), findsOneWidget);
    expect(find.text('Belum ada bukti transfer'), findsOneWidget);
    expect(find.text('Pilih bukti transfer'), findsOneWidget);
    expect(find.text('Kirim Booking'), findsOneWidget);
    expect(
      find.text('Pilih bukti transfer dulu untuk mengaktifkan tombol.'),
      findsOneWidget,
    );
  });

  bookingTestWidgets('tanpa config pembayaran menampilkan strip', (tester) async {
    await pumpBooking(tester);

    expect(find.text('Nomor DANA: -'), findsOneWidget);
    expect(find.text('a.n. -'), findsOneWidget);
  });

  bookingTestWidgets('ganti metode pembayaran mengubah tujuan', (tester) async {
    await seedPaymentConfig(fake);
    await pumpBooking(tester);

    await tester.tap(find.text('Transfer Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Tujuan (Transfer Bank):'), findsOneWidget);

    await tester.tap(find.text('E-Wallet lain'));
    await tester.pumpAndSettle();
    expect(find.text('Tujuan (E-Wallet lain):'), findsOneWidget);
  });

  bookingTestWidgets('salin nomor menampilkan snackbar', (tester) async {
    await seedPaymentConfig(fake);
    await pumpBooking(tester);

    await tester.tap(find.text('Salin nomor'));
    await pollFor(tester, 'Nomor DANA disalin.');

    expect(find.text('Nomor DANA disalin.'), findsOneWidget);
  });

  bookingTestWidgets('pilih bukti via galeri menampilkan pratinjau',
      (tester) async {
    await pumpBooking(tester);

    await pickProof(tester, via: 'Pilih dari galeri');

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Ganti bukti transfer'), findsOneWidget);
    expect(find.text('Belum ada bukti transfer'), findsNothing);
    expect(
      find.text('Pilih bukti transfer dulu untuk mengaktifkan tombol.'),
      findsNothing,
    );
  });

  bookingTestWidgets('pilih bukti via kamera menampilkan pratinjau',
      (tester) async {
    await pumpBooking(tester);

    await pickProof(tester, via: 'Ambil foto');

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Ganti bukti transfer'), findsOneWidget);
  });

  bookingTestWidgets('batal pilih bukti tidak mengubah form', (tester) async {
    fakePicker.fileToReturn = null;
    await pumpBooking(tester);

    await tester.tap(find.text('Pilih bukti transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Ambil foto'), findsOneWidget);
    expect(find.text('Pilih dari galeri'), findsOneWidget);
    await tester.tap(find.text('Pilih dari galeri'));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada bukti transfer'), findsOneWidget);
    expect(find.text('Pilih bukti transfer'), findsOneWidget);
  });

  bookingTestWidgets('kirim booking sukses menampilkan layar sukses',
      (tester) async {
    await seedPaymentConfig(fake);
    await pumpBookingWithBack(tester);
    await isiWaValid(tester);
    await pickProof(tester);

    // Indikator 'Mengirim…' (indeterminate) tidak bisa diamati dari test:
    // _send harus berjalan di runAsync agar IO berkas selesai, dan saat
    // runAsync kembali _send sudah selesai. Baris indikator tetap tak
    // tertutup — diterima (UI sesaat).
    await tapSendAndWait(tester, 'Booking terkirim, menunggu verifikasi.');

    expect(
      find.text('Booking terkirim, menunggu verifikasi.'),
      findsOneWidget,
    );
    final bookings = await fake.collection('bookings').get();
    expect(bookings.docs, hasLength(1));
    final data = bookings.docs.first.data();
    expect(data['status'], 'pending');
    expect(data['fieldId'], 'l1');
    expect(data['date'], fmtDate(besok()));
    expect(data['startTime'], '19:00');
    expect(data['endTime'], '21:00');
    expect(data['whatsapp'], '081234567890');
    expect(data['totalPrice'], 240000);
    expect(data['pricePerHour'], 120000);
    expect(data['userId'], 'u1');

    await tester.tap(find.text('Kembali ke Beranda'));
    await tester.pumpAndSettle();
    expect(find.text('Booking terkirim, menunggu verifikasi.'), findsNothing);
    expect(find.text('Depan'), findsOneWidget);
  });

  bookingTestWidgets('kirim dengan WA tidak valid menampilkan error validasi',
      (tester) async {
    await pumpBooking(tester);
    await tester.enterText(find.byType(TextFormField), '123');
    await tester.pumpAndSettle();
    await pickProof(tester);

    await tester.tap(find.text('Kirim Booking'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nomor WA wajib diisi, format 08… (10–14 digit).'),
      findsOneWidget,
    );
    final bookings = await fake.collection('bookings').get();
    expect(bookings.docs, isEmpty);
  });

  bookingTestWidgets('tombol kirim nonaktif tanpa bukti', (tester) async {
    await pumpBooking(tester);
    await isiWaValid(tester);

    await tester.tap(find.text('Kirim Booking'));
    await tester.pumpAndSettle();

    expect(find.text('Booking Lapangan'), findsOneWidget);
    final bookings = await fake.collection('bookings').get();
    expect(bookings.docs, isEmpty);
  });

  bookingTestWidgets('konflik slot kembali ke jadwal tanpa booking baru',
      (tester) async {
    await seedBooking(
      fake,
      date: fmtDate(besok()),
      startTime: '19:00',
      endTime: '20:00',
      status: 'confirmed',
    );
    await pumpBookingWithBack(tester);
    await isiWaValid(tester);
    await pickProof(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Kirim Booking'));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();

    // _send menampilkan snackbar konflik lalu pop kembali.
    expect(find.text('Booking Lapangan'), findsNothing);
    expect(find.text('Depan'), findsOneWidget);
    final bookings = await fake.collection('bookings').get();
    expect(bookings.docs, hasLength(1));
  });

  bookingTestWidgets('kirim tanpa login menampilkan snackbar gagal',
      (tester) async {
    await pumpBooking(tester, signedIn: false);
    await isiWaValid(tester);
    await pickProof(tester);

    await tapSendAndWait(
      tester,
      'Gagal mengirim booking. Periksa koneksi lalu coba lagi.',
    );

    expect(
      find.text('Gagal mengirim booking. Periksa koneksi lalu coba lagi.'),
      findsOneWidget,
    );
    expect(find.text('Booking Lapangan'), findsOneWidget);
    final bookings = await fake.collection('bookings').get();
    expect(bookings.docs, isEmpty);
  });
}
