import 'package:flutter/material.dart';

/// Token gerak Fase G (SPEK-DESAIN-FASE-G §2).
///
/// Aturan keras: ease-in dilarang; hanya transform & opacity yang
/// dianimasikan; reduced motion (MediaQuery.disableAnimations)
/// dihormati — animasi dekoratif mati, fungsi tetap sama.
class PitchMotion {
  // Kurva (§2.1)
  static const Cubic easeOut = Cubic(0.23, 1, 0.32, 1);
  static const Cubic easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const Cubic easeDrawer = Cubic(0.32, 0.72, 0, 1);

  // Durasi (§2.2)
  /// Umpan balik tekan (100–160 ms).
  static const Duration press = Duration(milliseconds: 160);

  /// Popover/kontrol kecil (125–200 ms).
  static const Duration popover = Duration(milliseconds: 175);

  /// Dropdown, chip, pergantian tab (150–250 ms).
  static const Duration control = Duration(milliseconds: 200);

  /// Perpindahan di dalam layar / transisi arah (250 ms).
  static const Duration screen = Duration(milliseconds: 250);

  /// Sheet & dialog (200–350 ms; plafon UI 300 ms).
  static const Duration sheet = Duration(milliseconds: 300);

  /// Skala elemen saat ditekan (§2.4 butir 1).
  static const double pressScale = 0.97;

  /// Skala awal elemen masuk (§2.4 butir 2: tidak pernah dari 0).
  static const double enterScale = 0.95;

  /// Pegas setara pendekatan Apple (§2.3): durasi perseptual
  /// ±0,4–0,5 dtk, bounce halus 0,1–0,25 (di bawah kendali
  /// damping ratio). Dipakai elemen hidup yang bisa disela di
  /// tengah gerak (seleksi sel slot, kartu geser, sheet).
  static SpringDescription spring({double bounce = 0.2}) {
    // bounce 0..0.25 dipetakan ke damping ratio 0.95..0.70:
    // makin besar bounce, makin rendah redaman.
    final ratio = 0.95 - bounce;
    return SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 260,
      ratio: ratio,
    );
  }

  /// Apakah sistem meminta gerak dikurangi (§2.4 butir 6).
  static bool reducedMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;
}

/// Transisi layar direction-aware (§3.1): maju = geser dari kanan,
/// kembali = sebaliknya (animasi yang sama diputar mundur oleh
/// Navigator). Hanya transform & opacity; mati bila reduced motion.
class PitchPageTransitionsBuilder extends PageTransitionsBuilder {
  const PitchPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (PitchMotion.reducedMotion(context)) return child;
    final position = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: PitchMotion.easeInOut),
    );
    final opacity = CurvedAnimation(
      parent: animation,
      curve: PitchMotion.easeOut,
    );
    return SlideTransition(
      position: position,
      child: FadeTransition(opacity: opacity, child: child),
    );
  }
}
