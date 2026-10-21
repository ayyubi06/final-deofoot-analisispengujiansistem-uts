import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deofoot/motion.dart';
import 'package:deofoot/theme.dart';

/// Pengunci token Fase G Tahap 1: nilai persis SPEK-DESAIN-FASE-G
/// §1–§2. Bila satu token bergeser dari spek, test ini merah.
void main() {
  // Getter tipografi memicu pemuatan font google_fonts, yang butuh
  // binding; matikan fetching runtime supaya test hermetis.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Token warna Pitch (§1.1)', () {
    test('nilai hex persis spek', () {
      expect(DeofootTheme.pitch900, const Color(0xFF0A231B));
      expect(DeofootTheme.pitch700, const Color(0xFF0E5C40));
      expect(DeofootTheme.pitch500, const Color(0xFF12805A));
      expect(DeofootTheme.volt, const Color(0xFFC6F135));
      expect(DeofootTheme.surfacePitch, const Color(0xFFF6F4EE));
      expect(DeofootTheme.card, const Color(0xFFFFFFFF));
      expect(DeofootTheme.ink60, const Color(0xFF5A6B63));
      expect(DeofootTheme.line, const Color(0xFFE4E1D8));
      expect(DeofootTheme.amber, const Color(0xFFD98E04));
      expect(DeofootTheme.red, const Color(0xFFD64545));
      expect(DeofootTheme.grey, const Color(0xFF8A948E));
    });

    test('alias peran lama menunjuk nilai Pitch', () {
      expect(DeofootTheme.primary, DeofootTheme.pitch700);
      expect(DeofootTheme.accent, DeofootTheme.pitch500);
      expect(DeofootTheme.background, DeofootTheme.surfacePitch);
      expect(DeofootTheme.textMuted, DeofootTheme.ink60);
      expect(DeofootTheme.booked, DeofootTheme.grey);
      expect(DeofootTheme.pending, DeofootTheme.amber);
      expect(DeofootTheme.danger, DeofootTheme.red);
    });

    test('statusColor mengikuti token status §1.1', () {
      expect(DeofootTheme.statusColor('pending'), DeofootTheme.amber);
      expect(DeofootTheme.statusColor('confirmed'), DeofootTheme.pitch700);
      expect(DeofootTheme.statusColor('rejected'), DeofootTheme.red);
      // Dibatalkan & Kedaluwarsa = grey (bukan merah seperti v0.4).
      expect(DeofootTheme.statusColor('cancelled'), DeofootTheme.grey);
      expect(DeofootTheme.statusColor('expired'), DeofootTheme.grey);
    });

    test('statusLabel tidak berubah dari v0.4', () {
      expect(DeofootTheme.statusLabel('pending'), 'Menunggu');
      expect(DeofootTheme.statusLabel('confirmed'), 'Disetujui');
      expect(DeofootTheme.statusLabel('rejected'), 'Ditolak');
      expect(DeofootTheme.statusLabel('cancelled'), 'Dibatalkan');
      expect(DeofootTheme.statusLabel('expired'), 'Kedaluwarsa');
    });
  });

  group('Bentuk (§1.3)', () {
    test('radius persis spek', () {
      expect(DeofootTheme.radiusCard, 20);
      expect(DeofootTheme.radiusSheet, 24);
      expect(DeofootTheme.radiusChip, 999);
      expect(DeofootTheme.radiusSlot, 12);
      expect(DeofootTheme.radiusButton, 14);
    });
  });

  group('Tipografi (§1.2)', () {
    test('skala ukuran persis spek', () {
      expect(DeofootTheme.displayStyle.fontSize, 28);
      expect(DeofootTheme.titleStyle.fontSize, 20);
      expect(DeofootTheme.bodyStyle.fontSize, 15);
      expect(DeofootTheme.captionStyle.fontSize, 12);
    });

    test('tabular() menambahkan tabular figures', () {
      final s = DeofootTheme.tabular(const TextStyle(fontSize: 15));
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('Token gerak (§2)', () {
    test('kurva persis spek', () {
      expect(PitchMotion.easeOut.a, 0.23);
      expect(PitchMotion.easeOut.b, 1.0);
      expect(PitchMotion.easeOut.c, 0.32);
      expect(PitchMotion.easeOut.d, 1.0);
      expect(PitchMotion.easeInOut.a, 0.77);
      expect(PitchMotion.easeInOut.b, 0.0);
      expect(PitchMotion.easeInOut.c, 0.175);
      expect(PitchMotion.easeInOut.d, 1.0);
      expect(PitchMotion.easeDrawer.a, 0.32);
      expect(PitchMotion.easeDrawer.b, 0.72);
      expect(PitchMotion.easeDrawer.c, 0.0);
      expect(PitchMotion.easeDrawer.d, 1.0);
    });

    test('durasi di dalam pita spek', () {
      expect(PitchMotion.press.inMilliseconds, inInclusiveRange(100, 160));
      expect(PitchMotion.popover.inMilliseconds, inInclusiveRange(125, 200));
      expect(PitchMotion.control.inMilliseconds, inInclusiveRange(150, 250));
      expect(PitchMotion.screen.inMilliseconds, 250);
      expect(PitchMotion.sheet.inMilliseconds, inInclusiveRange(200, 350));
    });

    test('skala tekan 0,97 & masuk dari 0,95', () {
      expect(PitchMotion.pressScale, 0.97);
      expect(PitchMotion.enterScale, 0.95);
    });

    test('pegas: bounce lebih besar = redaman lebih rendah', () {
      final soft = PitchMotion.spring(bounce: 0.1);
      final lively = PitchMotion.spring(bounce: 0.25);
      expect(lively.damping, lessThan(soft.damping));
      expect(soft.damping, greaterThan(0));
    });
  });
}
