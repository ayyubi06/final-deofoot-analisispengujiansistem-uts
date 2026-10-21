import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/calendar_logic.dart';
import 'package:deofoot/theme.dart';
import 'package:deofoot/widgets/calendar_sheet.dart';
import 'package:deofoot/widgets/pitch_components.dart';
import 'package:deofoot/widgets/slot_grid.dart';

/// Test perilaku Fase G Tahap 3 (§3.3): bahasa visual sel grid,
/// tap hanya pada sel bebas, grid stabil antar rebuild (anti-kedip
/// butir 1), efek tukar hadir saat kunci berubah (butir 2),
/// kalender memilih tanggal & menandai Penuh, ticker angka.
void main() {
  Widget wrap(Widget child, {bool reducedMotion = false}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  Map<int, SlotStatus> baseStatuses() => {
        for (var h = openHour; h < closeHour; h++) h: SlotStatus.free,
      };

  testWidgets('SlotGrid: sel terpilih volt, terisi tercoret, pending berlabel',
      (tester) async {
    final statuses = baseStatuses()
      ..[10] = SlotStatus.booked
      ..[11] = SlotStatus.pending;
    await tester.pumpWidget(wrap(SlotGrid(
      statuses: statuses,
      selection: const SlotSelection(9, 10),
      isPast: (_) => false,
      interactive: true,
      onTapHour: (_) {},
    )));
    // Sel terpilih (09.00): dekorasi volt.
    final selectedTile = find.ancestor(
      of: find.text('09.00'),
      matching: find.byType(AnimatedContainer),
    );
    final deco = tester
        .widget<AnimatedContainer>(selectedTile)
        .decoration! as BoxDecoration;
    expect(deco.color, DeofootTheme.volt);
    // Sel terisi (10.00): teks tercoret.
    final bookedText = tester.widget<Text>(find.text('10.00'));
    expect(bookedText.style!.decoration, TextDecoration.lineThrough);
    // Sel pending (11.00): label Menunggu tampil.
    expect(find.text('Menunggu'), findsOneWidget);
  });

  testWidgets('SlotGrid: tap hanya memicu pada sel bebas interaktif',
      (tester) async {
    final tapped = <int>[];
    final statuses = baseStatuses()..[10] = SlotStatus.booked;
    await tester.pumpWidget(wrap(SlotGrid(
      statuses: statuses,
      selection: const SlotSelection.empty(),
      isPast: (h) => h == 12,
      interactive: true,
      onTapHour: tapped.add,
    )));
    await tester.tap(find.text('09.00')); // bebas
    await tester.tap(find.text('10.00')); // terisi
    await tester.tap(find.text('12.00')); // lewat
    await tester.pump();
    expect(tapped, [9]);
  });

  testWidgets(
      'SlotGrid stabil antar rebuild: jumlah sel tetap & status baru tampil',
      (tester) async {
    final a = baseStatuses();
    await tester.pumpWidget(wrap(SlotGrid(
      statuses: a,
      selection: const SlotSelection.empty(),
      isPast: (_) => false,
      interactive: true,
      onTapHour: (_) {},
    )));
    final cellsBefore =
        find.byType(AnimatedContainer).evaluate().length;
    final b = baseStatuses()..[14] = SlotStatus.booked;
    await tester.pumpWidget(wrap(SlotGrid(
      statuses: b,
      selection: const SlotSelection.empty(),
      isPast: (_) => false,
      interactive: true,
      onTapHour: (_) {},
    )));
    await tester.pump();
    // Tidak ada grid yang dikosongkan/digambar ulang total:
    // jumlah sel sama, dan status baru (14.00 terisi) tercermin.
    expect(find.byType(AnimatedContainer).evaluate().length, cellsBefore);
    final bookedText = tester.widget<Text>(find.text('14.00'));
    expect(bookedText.style!.decoration, TextDecoration.lineThrough);
  });

  testWidgets('StatusSwapFade: anak selalu tampil; kunci berubah -> berdenyut',
      (tester) async {
    Widget tree(Object key) => wrap(
          StatusSwapFade(swapKey: key, child: const Text('GRID')),
        );
    await tester.pumpWidget(tree('a'));
    expect(find.text('GRID'), findsOneWidget);
    await tester.pumpWidget(tree('b'));
    await tester.pump(const Duration(milliseconds: 90));
    // Di tengah denyut ada ImageFiltered (blur sesaat).
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.text('GRID'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.text('GRID'), findsOneWidget);
  });

  testWidgets('NumberTicker menetap di nilai baru', (tester) async {
    Widget tree(int v) => wrap(NumberTicker(
          value: v,
          format: fmtRupiah,
          style: const TextStyle(fontSize: 16),
        ));
    await tester.pumpWidget(tree(120000));
    expect(find.text('Rp120.000'), findsOneWidget);
    await tester.pumpWidget(tree(240000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rp240.000'), findsOneWidget);
  });

  testWidgets(
      'CalendarSheet: tap tanggal depan memilih; lampau tidak; Penuh tampil',
      (tester) async {
    final today = DateTime(2026, 10, 21);
    final days = List.generate(60, (i) => today.add(Duration(days: i)));
    DateTime? picked;
    await tester.pumpWidget(wrap(CalendarSheet(
      days: days,
      selected: today,
      today: today,
      marks: {fmtDate(DateTime(2026, 10, 23)): DayMark.full},
      marksLoaded: true,
      onSelect: (d) => picked = d,
    )));
    // Label Penuh untuk 23 Okt.
    expect(find.text('Penuh'), findsOneWidget);
    // Tap tanggal 24 (belum tentu terlihat: scroll tidak perlu —
    // 24 ada di bulan yang sama, di bawah header; gunakan tap pada
    // teks angka yang tampil di viewport awal bila ada, bila tidak
    // geser dulu).
    final t24 = find.text('24');
    if (t24.evaluate().isEmpty) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('24'));
    await tester.pump();
    expect(picked, DateTime(2026, 10, 24));
  });

  testWidgets('CalendarSheet: tanggal lampau tidak bisa dipilih',
      (tester) async {
    final today = DateTime(2026, 10, 21);
    // Rentang dimulai 2 hari lalu (mensimulasikan pemanggilan yang
    // menyertakan lampau — sheet sendiri tidak menyaring).
    final days = List.generate(
      10,
      (i) => today.subtract(const Duration(days: 2)).add(Duration(days: i)),
    );
    DateTime? picked;
    await tester.pumpWidget(wrap(CalendarSheet(
      days: days,
      selected: today,
      today: today,
      marks: const {},
      marksLoaded: false,
      onSelect: (d) => picked = d,
    )));
    await tester.tap(find.text('19'));
    await tester.pump();
    expect(picked, isNull);
  });
}
