import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

/// Komponen dasar Fase G (SPEK-DESAIN-FASE-G §6 tahap 1):
/// tombol tekan 0,97, kartu, chip, sheet. Semua animasi hanya
/// transform & opacity, dan menghormati reduced motion.

/// Pembungkus tekan: elemen menyusut ke 0,97 saat ditekan
/// (160 ms easeOut, §2.4 butir 1). Mati bila reduced motion.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduced = PitchMotion.reducedMotion(context);
    final scale = reduced || !_pressed ? 1.0 : PitchMotion.pressScale;
    // Skala digerakkan Listener (peristiwa pointer mentah, instan)
    // — bukan onTapDown GestureDetector yang menunggu arena
    // gesture selesai, karena umpan balik tekan harus seketika.
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: PitchMotion.press,
          curve: PitchMotion.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

enum PitchButtonVariant { primary, volt, danger }

/// Tombol primer Pitch: radius 14, umpan balik tekan 0,97.
/// Varian volt = CTA di permukaan gelap (teks pitch900, §1.1);
/// danger = aksi destruktif (teks putih di atas red).
class PitchButton extends StatelessWidget {
  const PitchButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PitchButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final PitchButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      PitchButtonVariant.primary => (DeofootTheme.pitch700, Colors.white),
      PitchButtonVariant.volt => (DeofootTheme.volt, DeofootTheme.pitch900),
      PitchButtonVariant.danger => (DeofootTheme.red, Colors.white),
    };
    final content = Container(
      height: 52,
      decoration: BoxDecoration(
        color: onPressed == null ? bg.withValues(alpha: 0.45) : bg,
        borderRadius: BorderRadius.circular(DeofootTheme.radiusButton),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: DeofootTheme.bodyStyle.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onPressed == null) return content;
    return Pressable(onTap: onPressed, child: content);
  }
}

/// Kartu Pitch: putih, radius 20, bayangan lembut dua lapis (§1.3).
/// Border hanya bila [borderColor] diberikan (keadaan terpilih/aktif).
class PitchCard extends StatelessWidget {
  const PitchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: DeofootTheme.card,
        borderRadius: BorderRadius.circular(DeofootTheme.radiusCard),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
        boxShadow: DeofootTheme.cardShadows,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, child: box);
  }
}

/// Chip Pitch: radius penuh (999). Terpilih = isi padat + teks
/// kontras; warna isi terpilih bisa diganti (mis. volt untuk
/// kalender) lewat [selectedColor]/[selectedTextColor].
class PitchChip extends StatelessWidget {
  const PitchChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.selectedColor = DeofootTheme.pitch700,
    this.selectedTextColor = Colors.white,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color selectedColor;
  final Color selectedTextColor;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: PitchMotion.control,
      curve: PitchMotion.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? selectedColor : DeofootTheme.card,
        borderRadius: BorderRadius.circular(DeofootTheme.radiusChip),
        boxShadow: selected ? null : DeofootTheme.cardShadows,
      ),
      child: Text(
        label,
        style: DeofootTheme.bodyStyle.copyWith(
          color: selected ? selectedTextColor : DeofootTheme.pitch900,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
    if (onTap == null) return chip;
    return Pressable(onTap: onTap, child: chip);
  }
}

/// Satu item pada [PitchNavBar].
class PitchNavItem {
  const PitchNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bottom navigation Pitch (§3.1): indikator pil di belakang ikon
/// aktif MENGGELINCIR antar tab (transform, 200 ms easeInOut);
/// ikon aktif pitch700, nonaktif ink60. Mati gesernya bila
/// reduced motion (durasi 0).
class PitchNavBar extends StatelessWidget {
  const PitchNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PitchNavItem> items;

  @override
  Widget build(BuildContext context) {
    final reduced = PitchMotion.reducedMotion(context);
    return Container(
      decoration: BoxDecoration(
        color: DeofootTheme.card,
        boxShadow: DeofootTheme.cardShadows,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              const pillWidth = 56.0;
              final pillX =
                  currentIndex * itemWidth + (itemWidth - pillWidth) / 2;
              return Stack(
                children: [
                  // Pil penanda yang menggelincir (transform murni).
                  AnimatedContainer(
                    duration:
                        reduced ? Duration.zero : PitchMotion.control,
                    curve: PitchMotion.easeInOut,
                    transform: Matrix4.translationValues(pillX, 6, 0),
                    width: pillWidth,
                    height: 32,
                    decoration: BoxDecoration(
                      color: DeofootTheme.pitch700.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  i == currentIndex
                                      ? items[i].activeIcon
                                      : items[i].icon,
                                  size: 24,
                                  color: i == currentIndex
                                      ? DeofootTheme.pitch700
                                      : DeofootTheme.ink60,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  items[i].label,
                                  style: DeofootTheme.captionStyle.copyWith(
                                    color: i == currentIndex
                                        ? DeofootTheme.pitch700
                                        : DeofootTheme.ink60,
                                    fontWeight: i == currentIndex
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Pembungkus masuk berjenjang (§3.2/§4): elemen masuk dari
/// scale 0,95 + fade, jeda ±35 ms per indeks (plafon 6 item),
/// HANYA pada pemuatan pertama — id yang sudah pernah tampil
/// tidak beranimasi lagi selama sesi aplikasi berjalan.
/// Reduced motion: tampil langsung tanpa animasi.
class PitchEntrance extends StatefulWidget {
  const PitchEntrance({
    super.key,
    required this.id,
    required this.index,
    required this.child,
  });

  final String id;
  final int index;
  final Widget child;

  /// Id yang sudah selesai beranimasi pada sesi ini.
  static final Set<String> _seen = <String>{};

  /// Untuk test: kosongkan catatan sesi.
  static void debugResetSeen() => _seen.clear();

  @override
  State<PitchEntrance> createState() => _PitchEntranceState();
}

class _PitchEntranceState extends State<PitchEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _animate = !PitchEntrance._seen.contains(widget.id);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    if (_animate) {
      PitchEntrance._seen.add(widget.id);
      final steps = widget.index > 6 ? 6 : widget.index;
      Future.delayed(Duration(milliseconds: 35 * steps), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate || PitchMotion.reducedMotion(context)) return widget.child;
    final curved = CurvedAnimation(parent: _ctrl, curve: PitchMotion.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: PitchMotion.enterScale, end: 1)
            .animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Kartu kerangka (skeleton) berbentuk kartu lapangan (§3.2):
/// dipakai saat memuat — bukan spinner di tengah layar kosong.
/// Sapuan shimmer bergerak lewat opacity; mati saat reduced motion.
class PitchSkeletonCard extends StatefulWidget {
  const PitchSkeletonCard({super.key});

  @override
  State<PitchSkeletonCard> createState() => _PitchSkeletonCardState();
}

class _PitchSkeletonCardState extends State<PitchSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _block(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: DeofootTheme.line,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = PitchMotion.reducedMotion(context);
    final card = PitchCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 150, color: DeofootTheme.line),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(160, 18),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _block(110, 22),
                    const Spacer(),
                    _block(80, 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (reduced) return card;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: PitchMotion.easeInOut),
      ),
      child: card,
    );
  }
}

/// Angka yang menghitung ke nilai baru (§3.3 bar bawah & §3.9):
/// nilai ditampilkan selalu tabular (pemanggil menyediakan style
/// tabular) dan berubah dengan animasi 250 ms easeOut dari nilai
/// sebelumnya — bukan dari nol. Reduced motion: seketika.
class NumberTicker extends StatefulWidget {
  const NumberTicker({
    super.key,
    required this.value,
    required this.format,
    required this.style,
  });

  final int value;
  final String Function(int) format;
  final TextStyle style;

  @override
  State<NumberTicker> createState() => _NumberTickerState();
}

class _NumberTickerState extends State<NumberTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late int _from;
  late int _shown;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
    _shown = widget.value;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        final t = PitchMotion.easeOut.transform(_ctrl.value);
        setState(() {
          _shown = (_from + (widget.value - _from) * t).round();
        });
      });
  }

  @override
  void didUpdateWidget(NumberTicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _shown;
      if (PitchMotion.reducedMotion(context)) {
        _shown = widget.value;
      } else {
        _ctrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(widget.format(_shown), style: widget.style);
}

/// Bottom sheet Pitch: radius atas 24, permukaan kartu, pegangan
/// seret tampil. Pemanggil mengatur tinggi/isi (mis. kalender 85%).
Future<T?> showPitchSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: DeofootTheme.card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DeofootTheme.radiusSheet),
      ),
    ),
    builder: builder,
  );
}


/// Bungkus tukar status (§3.3 anti-kedip butir 2): saat [swapKey]
/// berubah, isi bertukar dengan denyut crossfade singkat + blur
/// 2px sesaat — tidak pernah ada frame kosong. Dipakai grid
/// Jadwal dan chip status Booking Saya (§3.6). Mati bila
/// reduced motion.
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
