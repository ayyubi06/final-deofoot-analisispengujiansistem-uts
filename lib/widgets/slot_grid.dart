import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../booking_logic.dart';
import '../motion.dart';
import '../theme.dart';
import 'pitch_components.dart';

/// Bungkus tukar status (§3.3 anti-kedip butir 2): saat [swapKey]
/// berubah (data tanggal baru tiba), isi bertukar dengan crossfade
/// singkat + blur 2px sesaat — tidak pernah ada frame kosong.
/// Mati bila reduced motion.
class StatusSwapFade extends StatefulWidget {
  const StatusSwapFade({super.key, required this.swapKey, required this.child});

  final Object swapKey;
  final Widget child;

  @override
  State<StatusSwapFade> createState() => _StatusSwapFadeState();
}

class _StatusSwapFadeState extends State<StatusSwapFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(StatusSwapFade old) {
    super.didUpdateWidget(old);
    if (old.swapKey != widget.swapKey &&
        !PitchMotion.reducedMotion(context)) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value; // 0..1
        final pulse = t >= 1 ? 0.0 : math.sin(t * math.pi);
        final sigma = 2.0 * pulse;
        final opacity = 1.0 - 0.12 * pulse;
        Widget w = Opacity(opacity: opacity, child: child);
        if (sigma > 0.05) {
          w = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: w,
          );
        }
        return w;
      },
      child: widget.child,
    );
  }
}

/// Grid slot Fase G §3.3: ubin tiket — jam besar tabular; Tersedia
/// = kartu putih bayangan lembut; Terpilih = isi volt + pop pegas;
/// Terisi = redup + jam tercoret tipis; Menunggu = garis miring
/// amber halus + label; Lewat = permukaan redup tanpa respons.
///
/// Sel dikunci per jam (ValueKey) dan state-nya persisten antar
/// rebuild/ganti tanggal: hanya sel yang berubah status yang
/// beranimasi (anti-kedip butir 1). Seleksi yang baru terbentuk
/// menyala berurutan dari blok lama ke ujung yang diketuk
/// (stagger ±20 ms per sel).
class SlotGrid extends StatefulWidget {
  const SlotGrid({
    super.key,
    required this.statuses,
    required this.selection,
    required this.isPast,
    required this.interactive,
    required this.onTapHour,
  });

  final Map<int, SlotStatus> statuses;
  final SlotSelection selection;
  final bool Function(int hour) isPast;
  final bool interactive;
  final void Function(int hour) onTapHour;

  @override
  State<SlotGrid> createState() => _SlotGridState();
}

class _SlotGridState extends State<SlotGrid> {
  Set<int> _prevSelected = <int>{};

  @override
  void didUpdateWidget(SlotGrid old) {
    super.didUpdateWidget(old);
    _prevSelected = {
      for (var h = openHour; h < closeHour; h++)
        if (old.selection.contains(h)) h,
    };
  }

  /// Jeda stagger untuk sel yang BARU terpilih: jarak jam dari
  /// blok seleksi sebelumnya (gelombang berjalan ke ujung rentang).
  int _waveDelayMs(int hour, Set<int> selectedNow) {
    if (_prevSelected.contains(hour) || !selectedNow.contains(hour)) {
      return 0;
    }
    if (_prevSelected.isEmpty) return 0;
    var best = 99;
    for (final o in _prevSelected) {
      final d = (hour - o).abs();
      if (d < best) best = d;
    }
    return (best - 1).clamp(0, 13) * 20;
  }

  @override
  Widget build(BuildContext context) {
    final selectedNow = {
      for (var h = openHour; h < closeHour; h++)
        if (widget.selection.contains(h)) h,
    };
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: closeHour - openHour,
      itemBuilder: (context, i) {
        final h = openHour + i;
        final st = widget.statuses[h] ?? SlotStatus.free;
        final past = widget.isPast(h) && st == SlotStatus.free;
        final selected = selectedNow.contains(h);
        return _SlotCell(
          key: ValueKey(h),
          hour: h,
          status: st,
          isPast: past,
          selected: selected,
          waveDelayMs: _waveDelayMs(h, selectedNow),
          onTap: widget.interactive && st == SlotStatus.free && !past
              ? () => widget.onTapHour(h)
              : null,
        );
      },
    );
  }
}

class _SlotCell extends StatefulWidget {
  const _SlotCell({
    super.key,
    required this.hour,
    required this.status,
    required this.isPast,
    required this.selected,
    required this.waveDelayMs,
    required this.onTap,
  });

  final int hour;
  final SlotStatus status;
  final bool isPast;
  final bool selected;
  final int waveDelayMs;
  final VoidCallback? onTap;

  @override
  State<_SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends State<_SlotCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(_SlotCell old) {
    super.didUpdateWidget(old);
    if (!old.selected && widget.selected) {
      // Pop pegas saat sel berubah jadi terpilih (§3.3): skala
      // 0,96 -> 1 dengan bounce 0,2, tertunda sesuai gelombang.
      final delay = widget.waveDelayMs;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted || !widget.selected) return;
        if (PitchMotion.reducedMotion(context)) {
          _pop.value = 1;
          return;
        }
        _pop.animateWith(
          SpringSimulation(PitchMotion.spring(bounce: 0.2), 0.96, 1, 0),
        );
      });
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final past = widget.isPast;
    final st = widget.status;

    final Color bg;
    if (sel) {
      bg = DeofootTheme.volt;
    } else if (past || st == SlotStatus.booked) {
      bg = DeofootTheme.surfacePitch;
    } else if (st == SlotStatus.pending) {
      bg = DeofootTheme.card;
    } else {
      bg = DeofootTheme.card;
    }

    final hourText = Text(
      hourLabel(widget.hour),
      style: DeofootTheme.tabular(
        TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: sel
              ? DeofootTheme.pitch900
              : past || st == SlotStatus.booked
                  ? DeofootTheme.ink60
                  : DeofootTheme.pitch900,
          decoration: !sel && st == SlotStatus.booked
              ? TextDecoration.lineThrough
              : null,
          decorationThickness: 1,
        ),
      ),
    );

    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sel) ...[
              const Icon(Icons.check, size: 15, color: DeofootTheme.pitch900),
              const SizedBox(width: 3),
            ],
            hourText,
          ],
        ),
        if (!sel && st == SlotStatus.pending)
          const Text(
            'Menunggu',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: DeofootTheme.amber,
            ),
          ),
      ],
    );

    if (!sel && st == SlotStatus.pending) {
      content = CustomPaint(
        painter: _StripePainter(),
        child: content,
      );
    }

    final tile = AnimatedContainer(
      duration: PitchMotion.control,
      curve: PitchMotion.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DeofootTheme.radiusSlot),
        boxShadow:
            sel || past || st == SlotStatus.booked ? null : DeofootTheme.cardShadows,
      ),
      child: content,
    );

    final scaled = AnimatedBuilder(
      animation: _pop,
      builder: (context, child) =>
          Transform.scale(scale: _pop.value, child: child),
      child: tile,
    );

    if (widget.onTap == null) return scaled;
    return Pressable(onTap: widget.onTap, child: scaled);
  }
}

/// Garis miring amber SANGAT halus untuk sel Menunggu (§3.3).
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DeofootTheme.amber.withValues(alpha: 0.07)
      ..strokeWidth = 5;
    for (var x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}
