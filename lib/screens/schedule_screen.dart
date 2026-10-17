import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../services/firestore_service.dart';
import 'booking_screen.dart';

/// Layar 4 — Jadwal lapangan: date picker 7 hari + grid slot 08.00–22.00.
/// Tap slot berurutan untuk booking multi-jam dalam 1 transaksi.
class ScheduleScreen extends StatefulWidget {
  final Field field;
  const ScheduleScreen({super.key, required this.field});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selected = DateTime.now();
  int? _selStart; // jam mulai pilihan (inklusif)
  int? _selEnd; // jam akhir pilihan (eksklusif)

  List<DateTime> get _days =>
      List.generate(7, (i) => DateTime.now().add(Duration(days: i)));

  @override
  void initState() {
    super.initState();
    // Expire booking pending basi (>30 mnt) - fire and forget.
    FirestoreService().expireStalePendings().then((_) {}, onError: (_) {});
  }

  bool _isSel(int h) =>
      _selStart != null && h >= _selStart! && h < _selEnd!;

  int get _selHours => _selStart == null ? 0 : _selEnd! - _selStart!;

  /// Tap slot: pilih / perpanjang rentang berurutan / batal pilih.
  void _tapSlot(int h, Map<int, SlotStatus> statuses) {
    if (_selStart == null) {
      setState(() {
        _selStart = h;
        _selEnd = h + 1;
      });
      return;
    }
    if (_selStart == h && _selEnd == h + 1) {
      setState(() {
        _selStart = null;
        _selEnd = null;
      });
      return;
    }
    final ns = min(_selStart!, h);
    final ne = max(_selEnd!, h + 1);
    for (var hh = ns; hh < ne; hh++) {
      if ((statuses[hh] ?? SlotStatus.free) != SlotStatus.free ||
          _isPastSlot(hh)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pilih jam berurutan yang masih bebas.')),
        );
        return;
      }
    }
    setState(() {
      _selStart = ns;
      _selEnd = ne;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final dateStr = fmtDate(_selected);
    return Scaffold(
      appBar: AppBar(title: Text('Jadwal — ${widget.field.name}')),
      body: Column(
        children: [
          // Date picker horizontal 7 hari
          SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _days.length,
              itemBuilder: (context, i) {
                final d = _days[i];
                final sel = fmtDate(d) == dateStr;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selected = d;
                    _selStart = null;
                    _selEnd = null;
                  }),
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: sel ? DeofootTheme.primary : DeofootTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel
                            ? DeofootTheme.primary
                            : DeofootTheme.booked,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel(d),
                          style: TextStyle(
                            fontSize: 12,
                            color: sel
                                ? Colors.white70
                                : DeofootTheme.textMuted,
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: sel
                                ? Colors.white
                                : DeofootTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Legenda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Legend(color: DeofootTheme.available, label: 'Bebas'),
                SizedBox(width: 16),
                _Legend(color: DeofootTheme.booked, label: 'Terisi'),
                SizedBox(width: 16),
                _Legend(color: DeofootTheme.pending, label: 'Menunggu'),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tap slot berurutan untuk booking lebih dari 1 jam.',
              style:
                  TextStyle(fontSize: 12, color: DeofootTheme.textMuted),
            ),
          ),
          // Grid slot
          Expanded(
            child: StreamBuilder<List<Booking>>(
              stream: fs.watchBookings(widget.field.id, dateStr),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final statuses = slotStatuses(
                    snap.data ?? [], widget.field.id, dateStr);
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 14,
                  itemBuilder: (context, i) {
                    final h = 8 + i;
                    final st = statuses[h] ?? SlotStatus.free;
                    final isPast = _isPastSlot(h);
                    final enabled =
                        st == SlotStatus.free && !isPast;
                    final sel = _isSel(h);
                    Color bg;
                    Color fg = Colors.white;
                    if (sel) {
                      bg = DeofootTheme.accent;
                    } else {
                      switch (st) {
                        case SlotStatus.free:
                          bg = isPast
                              ? DeofootTheme.booked
                              : DeofootTheme.available;
                          break;
                        case SlotStatus.booked:
                          bg = DeofootTheme.booked;
                          fg = DeofootTheme.textMuted;
                          break;
                        case SlotStatus.pending:
                          bg = DeofootTheme.pending;
                          break;
                      }
                    }
                    return ElevatedButton(
                      onPressed: enabled
                          ? () => _tapSlot(h, statuses)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bg,
                        foregroundColor: fg,
                        disabledBackgroundColor: bg,
                        disabledForegroundColor: fg,
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        hourLabel(h),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selStart == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(
                        field: widget.field,
                        date: _selected,
                        startHour: _selStart!,
                        endHour: _selEnd!,
                      ),
                    ),
                  ),
                  child: Text(
                      'Lanjut — $_selHours jam (${fmtRupiah(_selHours * widget.field.pricePerHour)})'),
                ),
              ),
            ),
    );
  }

  bool _isPastSlot(int hour) {
    final now = DateTime.now();
    final sel = _selected;
    if (fmtDate(sel) != fmtDate(now)) return false;
    return hour <= now.hour;
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

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
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: DeofootTheme.textMuted)),
      ],
    );
  }
}
