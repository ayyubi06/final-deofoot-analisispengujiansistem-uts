import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deofoot/motion.dart';
import 'package:deofoot/theme.dart';
import 'package:deofoot/widgets/pitch_components.dart';

/// Test perilaku Fase G Tahap 2 (§3.1–§3.2): indikator nav
/// menggelincir lewat transform, entrance hanya pada pemuatan
/// pertama per sesi, skeleton tampil, transisi layar geser arah.
void main() {
  const items = [
    PitchNavItem(
        icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Beranda'),
    PitchNavItem(
        icon: Icons.receipt_outlined,
        activeIcon: Icons.receipt,
        label: 'Booking Saya'),
    PitchNavItem(
        icon: Icons.person_outlined, activeIcon: Icons.person, label: 'Profil'),
  ];

  Widget wrap(Widget child, {bool reducedMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  double pillDx(WidgetTester tester) {
    final c = tester.widget<AnimatedContainer>(
      find.descendant(
          of: find.byType(PitchNavBar),
          matching: find.byType(AnimatedContainer)),
    );
    return c.transform!.storage[12];
  }

  testWidgets('PitchNavBar: tap memicu onTap & pil menggelincir ke tab baru',
      (tester) async {
    var tapped = -1;
    Widget nav(int idx) => PitchNavBar(
          currentIndex: idx,
          onTap: (i) => tapped = i,
          items: items,
        );
    await tester.pumpWidget(wrap(nav(0)));
    final dx0 = pillDx(tester);
    await tester.tap(find.text('Profil'));
    expect(tapped, 2);
    await tester.pumpWidget(wrap(nav(2)));
    await tester.pump();
    await tester.pump(PitchMotion.control + const Duration(milliseconds: 40));
    final dx2 = pillDx(tester);
    expect(dx2, greaterThan(dx0 + 100));
  });

  testWidgets('PitchNavBar: reduced motion — pil berpindah seketika',
      (tester) async {
    Widget nav(int idx) => PitchNavBar(
          currentIndex: idx,
          onTap: (_) {},
          items: items,
        );
    await tester.pumpWidget(wrap(nav(0), reducedMotion: true));
    final dx0 = pillDx(tester);
    await tester.pumpWidget(wrap(nav(1), reducedMotion: true));
    await tester.pump();
    expect(pillDx(tester), greaterThan(dx0 + 100));
  });

  testWidgets('PitchEntrance: beranimasi sekali per id dalam satu sesi',
      (tester) async {
    PitchEntrance.debugResetSeen();
    Widget tree(String id) => wrap(
          PitchEntrance(
            key: ValueKey(id),
            id: id,
            index: 0,
            child: const Text('Kartu'),
          ),
        );
    await tester.pumpWidget(tree('a'));
    await tester.pump();
    // Sedang beranimasi masuk: ada FadeTransition membungkus.
    expect(
      find.descendant(
          of: find.byType(PitchEntrance),
          matching: find.byType(FadeTransition)),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 300));
    // Bongkar lalu pasang lagi id yang sama: tanpa animasi.
    await tester.pumpWidget(wrap(const Text('lain')));
    await tester.pumpWidget(tree('a'));
    expect(
      find.descendant(
          of: find.byType(PitchEntrance),
          matching: find.byType(FadeTransition)),
      findsNothing,
    );
    // Id baru tetap beranimasi.
    await tester.pumpWidget(tree('b'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.descendant(
          of: find.byType(PitchEntrance),
          matching: find.byType(FadeTransition)),
      findsOneWidget,
    );
    // Kuras timer & animasi agar tidak ada timer tertunda di akhir.
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('PitchSkeletonCard tampil tanpa error', (tester) async {
    await tester.pumpWidget(wrap(const PitchSkeletonCard()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PitchCard), findsOneWidget);
    await tester.pumpWidget(wrap(const PitchSkeletonCard(), reducedMotion: true));
    expect(find.byType(PitchCard), findsOneWidget);
  });

  testWidgets('Transisi layar: halaman baru menggeser masuk lalu menetap',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DeofootTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const Scaffold(body: Text('Halaman tujuan')),
                ),
              ),
              child: const Text('Pergi'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pergi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Di tengah transisi ada SlideTransition aktif.
    expect(find.byType(SlideTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Halaman tujuan'), findsOneWidget);
  });
}
