import 'package:flutter/material.dart';

import '../availability_logic.dart';
import '../booking_logic.dart';
import '../calendar_logic.dart';
import '../models.dart';
import '../motion.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/calendar_sheet.dart';
import '../widgets/pitch_components.dart';
import '../widgets/slot_grid.dart';
import 'booking_screen.dart';
import 'recurring_screen.dart';

/// Layar 4 — Jadwal lapangan (Fase G §3.3): field tanggal membuka
/// kalender sheet (G5/G6/G8), grid ubin tiket baru, dan obat kedip:
/// data lama tetap tampil sampai data tanggal baru siap, lalu
/// bertukar lewat crossfade+blur singkat (StatusSwapFade); grid
/// tidak pernah dikosongkan saat berpindah tanggal.
/// Semantik beku dari v0.4.1: slot 60 menit, grid 08–22, seleksi
/// satu blok berurutan via toggleSlot, tanggal berganti -> seleksi
/// kosong, rentang tanggal dari bookingDateRange.
class ScheduleScreen extends StatefulWidget {
  final Field field;

  /// Tanggal awal yang dipilih (mis. dari Pencarian Slot, Fase D).
  /// Di luar rentang booking -> kembali ke hari ini.
  final DateTime? initialDate;

  /// Pra-seleksi dari Cari Slot (Fase G §3.4): jam mulai + durasi
  /// hasil pencarian. Diterapkan SATU KALI saat status pertama
  /// tiba, hanya bila seluruh rentangnya masih bebas & belum
  /// lewat (canPreselect) — selain itu seleksi mulai kosong
  /// seperti biasa.
  final int? initialStartHour;
  final int? initialDuration;
  const ScheduleScreen({
    super.key,
    required this.field,
    this.initialDate,
    this.initialStartHour,
    this.initialDuration,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selected;
  SlotSelection _sel = const SlotSelection.empty();

  /// Status terakhir yang diketahui (anti-kedip): ditampilkan terus
  /// selama data tanggal baru belum tiba.
  Map<int, SlotStatus>? _lastStatuses;
  String? _lastDateStr;

  /// Pra-seleksi Cari Slot hanya dicoba satu kali.
  bool _preselectDone = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final awal = widget.initialDate;
    if (awal == null) {
      _selected = now;
    } else {
      final d = DateTime(awal.year, awal.month, awal.day);
      _selected = (d.isBefore(today) ||
              d.isAfter(today.add(const Duration(days: 89))))
          ? today
          : d;
    }
    // Expire booking pending basi (>30 mnt) - fire and forget.
    FirestoreService().expireStalePendings().then((_) {}, onError: (_) {});
  }

  /// Tap slot: toggle pilih/batal via aturan [toggleSlot].
  void _tapSlot(int h, Map<int, SlotStatus> statuses) {
    final now = DateTime.now();
    bool selectable(int hh) =>
        (statuses[hh] ?? SlotStatus.free) == SlotStatus.free &&
        !isPastSlot(_selected, hh, now);
    setState(() {
      _sel = toggleSlot(_sel, h, selectable);
    });
  }

  void _openCalendar() {
    final fs = FirestoreService();
    final days = bookingDateRange(DateTime.now());
    showPitchSheet<void>(
      context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StreamBuilder<List<Booking>>(
          stream: fs.watchBookingsInRange(
            fmtDate(days.first),
            fmtDate(days.last),
          ),
          builder: (context, snap) {
            final now = DateTime.now();
            final marks = <String, DayMark>{};
            if (snap.hasData) {
              for (final d in days) {
                marks[fmtDate(d)] =
                    dayMark(snap.data!, widget.field.id, d, now);
              }
            }
            return CalendarSheet(
              days: days,
              selected: _selected,
              today: now,
              marks: marks,
              marksLoaded: snap.hasData,
              onSelect: (d) => setState(() {
                _selected = d;
                _sel = const SlotSelection.empty();
              }),
            );
          },
        );
      },
    );
  }

  static bool _sameStatuses(
    Map<int, SlotStatus> a,
    Map<int, SlotStatus> b,
  ) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  static String _statusHash(Map<int, SlotStatus> s) => s.entries
      .where((e) => e.value != SlotStatus.free)
      .map((e) => '${e.key}:${e.value.index}')
      .join(',');

  Widget _skeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: closeHour - openHour,
      itemBuilder: (context, i) => Container(
        decoration: BoxDecoration(
          color: DeofootTheme.line,
          borderRadius: BorderRadius.circular(DeofootTheme.radiusSlot),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final dateStr = fmtDate(_selected);
    // Lapangan nonaktif tidak bisa dibooking (Fase C).
    if (!widget.field.isActive) {
      return Scaffold(
        appBar: AppBar(title: Text('Jadwal — ${widget.field.name}')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Lapangan ini sedang nonaktif dan tidak menerima booking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DeofootTheme.textMuted),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Jadwal — ${widget.field.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'Langganan rutin',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecurringScreen(
                  field: widget.field,
                  initialDate: _selected,
                  initialStartHour: _sel.isEmpty ? null : _sel.start,
                  initialDuration: _sel.isEmpty ? null : _sel.hours,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Aksen warna identitas lapangan.
          Container(height: 4, color: widget.field.color),
          // Field tanggal -> kalender sheet (§3.3).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: PitchCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: _openCalendar,
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: DeofootTheme.pitch700,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanggal main',
                        style: DeofootTheme.captionStyle,
                      ),
                      Text(
                        indoFullDate(_selected),
                        style: DeofootTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.expand_more,
                    color: DeofootTheme.ink60,
                  ),
                ],
              ),
            ),
          ),
          // Legenda + keterangan grid (§3.3: "60 mnt" cukup di kepala).
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(
                  color: DeofootTheme.card,
                  border: true,
                  label: 'Bebas',
                ),
                SizedBox(width: 12),
                _Legend(color: DeofootTheme.grey, label: 'Terisi'),
                SizedBox(width: 12),
                _Legend(color: DeofootTheme.amber, label: 'Menunggu'),
                SizedBox(width: 12),
                _Legend(color: DeofootTheme.line, label: 'Lewat'),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Slot 60 menit · 08.00–22.00 — tap slot bebas untuk pilih, tap lagi untuk batal. Seleksi selalu berurutan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: DeofootTheme.textMuted),
            ),
          ),
          // Grid slot anti-kedip.
          Expanded(
            child: StreamBuilder<List<Booking>>(
              stream: fs.watchBookings(widget.field.id, dateStr),
              builder: (context, snap) {
                // Snapshot saat waiting bisa masih membawa data
                // tanggal lama — jangan dipakai untuk tanggal baru
                // (itulah sumber kedip v0.4). Data lama yang sudah
                // dirender dipertahankan sampai data baru tiba.
                final usable = snap.hasData &&
                    snap.connectionState != ConnectionState.waiting;
                if (usable) {
                  final statuses =
                      slotStatuses(snap.data!, widget.field.id, dateStr);
                  if (_lastStatuses == null ||
                      _lastDateStr != dateStr ||
                      !_sameStatuses(_lastStatuses!, statuses)) {
                    _lastStatuses = statuses;
                    _lastDateStr = dateStr;
                  }
                  // Pra-seleksi dari Cari Slot (§3.4): satu kali,
                  // hanya bila rentangnya masih sahih bebas.
                  if (!_preselectDone) {
                    _preselectDone = true;
                    final s = widget.initialStartHour;
                    final d = widget.initialDuration;
                    if (s != null &&
                        d != null &&
                        canPreselect(
                          statuses,
                          s,
                          d,
                          (h) => isPastSlot(_selected, h, DateTime.now()),
                        )) {
                      _sel = SlotSelection(s, s + d);
                    }
                  }
                }
                if (_lastStatuses == null) return _skeletonGrid();
                final show = _lastStatuses!;
                final waiting =
                    snap.connectionState == ConnectionState.waiting;
                return StatusSwapFade(
                  swapKey: '$_lastDateStr|${_statusHash(show)}',
                  child: SlotGrid(
                    statuses: show,
                    selection: _sel,
                    isPast: (h) =>
                        isPastSlot(_selected, h, DateTime.now()),
                    // Selama data tanggal baru belum tiba, grid
                    // tampil stabil tapi tidak menerima tap (cegah
                    // memilih dari data basi).
                    interactive: !waiting,
                    onTapHour: (h) => _tapSlot(h, show),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Bar bawah TINGGI TETAP: grid tidak pernah bergeser kasar
      // (§3.3) — isi bar bertukar dengan crossfade.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: DeofootTheme.card,
          boxShadow: DeofootTheme.cardShadows,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 84,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: PitchMotion.control,
                switchInCurve: PitchMotion.easeOut,
                child: _sel.isEmpty
                    ? Row(
                        key: const ValueKey('hint'),
                        children: [
                          const Icon(
                            Icons.touch_app_outlined,
                            color: DeofootTheme.ink60,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Pilih slot bebas untuk melanjutkan',
                            style: DeofootTheme.bodyStyle.copyWith(
                              color: DeofootTheme.ink60,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('ringkasan'),
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_sel.hours} jam · ${hourLabel(_sel.start!)}–${hourLabel(_sel.end!)}',
                                  style: DeofootTheme.captionStyle,
                                ),
                                NumberTicker(
                                  value: bookingTotal(
                                    _sel.hours,
                                    widget.field.pricePerHour,
                                  ),
                                  format: fmtRupiah,
                                  style: DeofootTheme.tabular(
                                    DeofootTheme.titleStyle.copyWith(
                                      color: DeofootTheme.pitch700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: PitchButton(
                              label: 'Lanjut',
                              icon: Icons.arrow_forward,
                              onPressed: () =>
                                  Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookingScreen(
                                    field: widget.field,
                                    date: _selected,
                                    startHour: _sel.start!,
                                    endHour: _sel.end!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool border;
  const _Legend({required this.color, required this.label, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border ? Border.all(color: DeofootTheme.line) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: DeofootTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
