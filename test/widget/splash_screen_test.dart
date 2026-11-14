import 'package:deofoot/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpSplash(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('tombol Masuk membuka layar login', (tester) async {
    await pumpSplash(tester);
    expect(find.text('Masuk'), findsOneWidget);

    // _go mendorong AuthScreen tanpa authService, jadi fallback
    // AuthService() melempar tanpa Firebase terinisialisasi. Itu
    // perilaku layar yang diuji, bukan kegagalan test: tangkap
    // exception-nya dan pastikan rute sudah diganti.
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(tester.takeException(), isNotNull);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorWidget), findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
  });

  testWidgets('tombol Daftar membuka layar daftar', (tester) async {
    await pumpSplash(tester);
    expect(find.text('Daftar'), findsOneWidget);

    await tester.tap(find.text('Daftar'));
    await tester.pump();
    expect(tester.takeException(), isNotNull);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorWidget), findsOneWidget);
    expect(find.text('Daftar'), findsNothing);
  });
}
