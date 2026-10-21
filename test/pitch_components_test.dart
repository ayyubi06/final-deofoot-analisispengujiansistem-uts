import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deofoot/motion.dart';
import 'package:deofoot/theme.dart';
import 'package:deofoot/widgets/pitch_components.dart';

/// Test perilaku komponen dasar Fase G Tahap 1 (§2.4 & §6.1):
/// tekan menyusut 0,97, reduced motion mematikan skala, kartu
/// radius 20, chip terpilih berwarna primer, tombol bisa ditekan.
void main() {
  Widget wrap(Widget child, {bool reducedMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  double scaleOf(WidgetTester tester) {
    final t = tester.widget<Transform>(
      find.descendant(of: find.byType(Pressable), matching: find.byType(Transform)),
    );
    return t.transform.storage[0];
  }

  testWidgets('Pressable menyusut ke 0,97 saat ditekan, kembali 1,0',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(Pressable(
      onTap: () => taps++,
      child: const SizedBox(width: 100, height: 50),
    )));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    // Dua langkah: pump pertama memproses event & memulai animasi,
    // pump kedua memajukan jam melewati durasi tekan.
    await tester.pump();
    await tester.pump(PitchMotion.press + const Duration(milliseconds: 40));
    expect(scaleOf(tester), closeTo(0.97, 0.001));
    await gesture.up();
    await tester.pump();
    await tester.pump(PitchMotion.press + const Duration(milliseconds: 40));
    expect(scaleOf(tester), closeTo(1.0, 0.001));
    expect(taps, 1);
  });

  testWidgets('Pressable tidak menyusut bila reduced motion aktif',
      (tester) async {
    await tester.pumpWidget(wrap(
      Pressable(
        onTap: () {},
        child: const SizedBox(width: 100, height: 50),
      ),
      reducedMotion: true,
    ));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    await tester.pump(PitchMotion.press + const Duration(milliseconds: 40));
    expect(scaleOf(tester), closeTo(1.0, 0.001));
    await gesture.up();
  });

  testWidgets('PitchButton menampilkan label & memicu onPressed',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(PitchButton(
      label: 'Lanjut',
      onPressed: () => taps++,
    )));
    expect(find.text('Lanjut'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('PitchCard radius 20 & menampilkan isi', (tester) async {
    await tester.pumpWidget(wrap(const PitchCard(child: Text('Isi kartu'))));
    expect(find.text('Isi kartu'), findsOneWidget);
    final container = tester.widget<Container>(
      find.descendant(
          of: find.byType(PitchCard), matching: find.byType(Container)),
    );
    final deco = container.decoration! as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(DeofootTheme.radiusCard));
    expect(deco.color, DeofootTheme.card);
    expect(deco.boxShadow, isNotEmpty);
  });

  testWidgets('PitchChip terpilih memakai warna primer & bisa ditekan',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(PitchChip(
      label: 'Futsal',
      selected: true,
      onTap: () => taps++,
    )));
    final animated = tester.widget<AnimatedContainer>(
      find.descendant(
          of: find.byType(PitchChip), matching: find.byType(AnimatedContainer)),
    );
    final deco = animated.decoration! as BoxDecoration;
    expect(deco.color, DeofootTheme.pitch700);
    expect(deco.borderRadius,
        BorderRadius.circular(DeofootTheme.radiusChip));
    await tester.tap(find.text('Futsal'));
    await tester.pump();
    expect(taps, 1);
  });
}
