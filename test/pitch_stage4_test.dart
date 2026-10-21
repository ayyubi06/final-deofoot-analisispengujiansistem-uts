import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deofoot/availability_logic.dart';
import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/screens/booking_screen.dart';

/// Test Fase G Tahap 4 (§3.4–§3.5): praseleksi Cari Slot hanya
/// bila rentang sahih bebas (canPreselect), dan layar sukses
/// booking — kalimat persis + centang pop pegas yang menetap.
void main() {
  Map<int, SlotStatus> allFree() => {
        for (var h = openHour; h < closeHour; h++) h: SlotStatus.free,
      };

  group('canPreselect (§3.4)', () {
    test('rentang bebas penuh -> true', () {
      expect(canPreselect(allFree(), 19, 2, (_) => false), isTrue);
    });

    test('satu jam terisi -> false', () {
      final s = allFree()..[20] = SlotStatus.booked;
      expect(canPreselect(s, 19, 2, (_) => false), isFalse);
    });

    test('satu jam pending -> false', () {
      final s = allFree()..[19] = SlotStatus.pending;
      expect(canPreselect(s, 19, 1, (_) => false), isFalse);
    });

    test('jam sudah lewat -> false', () {
      expect(canPreselect(allFree(), 19, 2, (h) => h == 19), isFalse);
    });

    test('rentang menembus tutup grid -> false', () {
      expect(canPreselect(allFree(), 21, 2, (_) => false), isFalse);
    });

    test('durasi tidak sah -> false', () {
      expect(canPreselect(allFree(), 19, 0, (_) => false), isFalse);
    });
  });

  Widget wrap(Widget child, {bool reducedMotion = false}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: child,
        ),
      ),
    );
  }

  double checkScale(WidgetTester tester) {
    // Lingkaran centang dikenali dari dekorasinya; Transform
    // terdekat di atasnya adalah Transform skala pop-in (Transform
    // transisi halaman juga ada di pohon — jangan tertukar).
    final circle = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle,
    );
    final transforms = find.ancestor(
      of: circle,
      matching: find.byType(Transform),
    );
    return tester.widgetList<Transform>(transforms).first.transform.storage[0];
  }

  testWidgets('BookingSuccessScreen: kalimat persis & tombol beranda',
      (tester) async {
    await tester.pumpWidget(wrap(const BookingSuccessScreen()));
    expect(
      find.text('Booking terkirim, menunggu verifikasi.'),
      findsOneWidget,
    );
    expect(find.text('Kembali ke Beranda'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('BookingSuccessScreen: pop pegas menetap di skala 1',
      (tester) async {
    await tester.pumpWidget(wrap(const BookingSuccessScreen()));
    await tester.pump(); // post-frame: pegas mulai dari 0,95
    final start = checkScale(tester);
    expect(start, lessThan(1.05));
    // Jalankan pegas sampai diam.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(checkScale(tester), closeTo(1.0, 0.01));
  });

  testWidgets('BookingSuccessScreen: reduced motion tanpa pegas',
      (tester) async {
    await tester.pumpWidget(
      wrap(const BookingSuccessScreen(), reducedMotion: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(checkScale(tester), closeTo(1.0, 0.001));
  });
}
