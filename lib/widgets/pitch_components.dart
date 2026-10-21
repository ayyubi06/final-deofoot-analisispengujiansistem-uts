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
