import 'package:flutter/material.dart';

import '../booking_logic.dart';
import '../calendar_logic.dart';
import '../motion.dart';
import '../theme.dart';

/// Sheet kalender Fase G §3.3 (G5 + G6 + G8): bulan-bulan ditumpuk
/// vertikal & bisa di-scroll sepanjang rentang tanggal booking,
/// header bulan sticky, tanggal lampau nonaktif, hari ini bercincin
/// volt, terpilih berisi volt, dan penanda ketersediaan per tanggal
/// (titik volt = masih ada slot; "Penuh" = habis).
///
/// Widget ini murni presentasi: hari, pilihan, dan penanda datang
/// dari pemanggil; memilih tanggal memanggil [onSelect] lalu
/// menutup sheet.
class CalendarSheet extends StatelessWidget {
  const CalendarSheet({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.marks,
    required this.marksLoaded,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final Map<String, DayMark> marks;
  final bool marksLoaded;
  final ValueChanged<DateTime> onSelect;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    // Kelompokkan hari berurutan per bulan.
    final months = <DateTime, List<DateTime>>{};
    for (final d in days) {
      months.putIfAbsent(DateTime(d.year, d.month), () => []).add(d);
    }
    final height = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
            child: Row(
              children: [
                Text('Pilih tanggal', style: DeofootTheme.titleStyle),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final w in const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DeofootTheme.ink60,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomScrollView(
              slivers: [
                for (final entry in months.entries) ...[
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _MonthHeaderDelegate(indoMonthYear(entry.key)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          // Sel kosong sebelum tanggal pertama yang
                          // tampil pada bulan ini, supaya tanggal
                          // sejajar kolom harinya (Senin = kolom 0).
                          // Berlaku juga untuk bulan pertama yang
                          // mulai di tengah bulan.
                          final first = entry.value.first;
                          final leading = first.weekday - 1;
                          if (i < leading) return const SizedBox.shrink();
                          final d = entry.value[i - leading];
                          return _DayCell(
                            date: d,
                            isPast: d.isBefore(
                              DateTime(today.year, today.month, today.day),
                            ),
                            isToday: _sameDay(d, today),
                            isSelected: _sameDay(d, selected),
                            mark: marksLoaded
                                ? (marks[fmtDate(d)] ?? DayMark.unknown)
                                : DayMark.unknown,
                            onTap: () {
                              onSelect(d);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                        childCount:
                            entry.value.length + entry.value.first.weekday - 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate(this.label);

  final String label;

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: DeofootTheme.card,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: DeofootTheme.bodyStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: DeofootTheme.pitch900,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate old) => old.label != label;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isPast,
    required this.isToday,
    required this.isSelected,
    required this.mark,
    required this.onTap,
  });

  final DateTime date;
  final bool isPast;
  final bool isToday;
  final bool isSelected;
  final DayMark mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final full = mark == DayMark.full && !isPast;
    final Color numberColor;
    if (isSelected) {
      numberColor = DeofootTheme.pitch900;
    } else if (isPast) {
      numberColor = DeofootTheme.ink60.withValues(alpha: 0.4);
    } else if (full) {
      numberColor = DeofootTheme.ink60;
    } else {
      numberColor = DeofootTheme.pitch900;
    }
    final circle = AnimatedContainer(
      duration: PitchMotion.popover,
      curve: PitchMotion.easeOut,
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? DeofootTheme.volt : Colors.transparent,
        border: isToday && !isSelected
            ? Border.all(color: DeofootTheme.volt, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontSize: 15,
          fontWeight:
              isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
          color: numberColor,
        ),
      ),
    );
    final cell = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 2),
        SizedBox(
          height: 10,
          child: full
              ? const Text(
                  'Penuh',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: DeofootTheme.grey,
                  ),
                )
              : mark == DayMark.hasFree && !isPast
                  ? Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: DeofootTheme.volt,
                      ),
                    )
                  : null,
        ),
      ],
    );
    if (isPast) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: cell,
    );
  }
}
