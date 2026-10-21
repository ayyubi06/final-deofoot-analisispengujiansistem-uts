import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deofoot/screens/profile_screen.dart';
import 'package:deofoot/screens/splash_screen.dart';

/// Test Fase G Tahap 7 (§3.9): wordmark Pitch di Splash,
/// animasi masuk SATU crossfade 250 ms (bukan stagger 900 ms),
/// dan label versi aplikasi untuk Profil.
void main() {
  double fadeOpacity(WidgetTester tester) {
    final fades = find.byType(FadeTransition);
    expect(fades, findsWidgets);
    return tester.widget<FadeTransition>(fades.first).opacity.value;
  }

  testWidgets('Splash: wordmark + crossfade 250 ms menetap penuh',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(); // post-frame: crossfade mulai
    expect(find.text('Booking futsal semudah itu.'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Daftar'), findsOneWidget);
    // Wordmark kaya: "Deofoot" + "." volt dalam satu Text.rich.
    final rich = tester.widget<Text>(find
        .byWidgetPredicate((w) => w is Text && w.textSpan != null)
        .first);
    final plain = rich.textSpan!.toPlainText();
    expect(plain, 'Deofoot.');
    // 250 ms crossfade: sesudah 300 ms opacity harus sudah 1.
    await tester.pump(const Duration(milliseconds: 300));
    expect(fadeOpacity(tester), closeTo(1.0, 0.001));
  });

  // CATATAN: AuthScreen tidak di-pump di sini — konstruktornya
  // mengikat Firebase (AuthService/FirestoreService dibuat sebagai
  // field), sama seperti Home & Booking Saya; tanpa mock Firebase
  // ia melempar saat build. Wordmark & crossfade-nya memakai pola
  // yang sama persis dengan Splash di atas (teruji); sisanya
  // terverifikasi analyze + QA perangkat inka.

  testWidgets('Splash: reduced motion tampil penuh seketika',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: true),
            child: const SplashScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(fadeOpacity(tester), closeTo(1.0, 0.001));
  });

  test('Label versi aplikasi selaras pubspec Fase G', () {
    expect(appVersionLabel, '1.5.0+7');
  });
}
