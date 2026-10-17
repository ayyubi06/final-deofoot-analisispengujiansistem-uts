import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../services/firestore_service.dart';
import 'booking_screen.dart';

/// Layar 4 — Jadwal lapangan: date picker 60 hari + grid slot 08.00–22.00.
/// Tap slot hijau → pilih; tap yang terpilih → batalkan.
/// Seleksi selalu satu blok berurutan.
class ScheduleScreen extends StatefulWidget {
  final Field field;
  const ScheduleScreen({super.key, required this.field});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selected = DateTime.now();
  SlotSelection _sel = const SlotSelection.empty();

  List<DateTime> get _days => bookingDateRange(DateTime.now());

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final dateStr = fmtDate(_selected);
    return Scaffold(
      appBar: AppBar(title: Text('Jadwal — ${widget.field.name}')),
      body: Column(
        children: [
          // Aksen warna identitas lapangan.
          Container(height: 4, color: widget.field.color),
          // Date picker horizontal 60 hari (hari ini → H+59)
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _days.length,
              itemBuilder: (context, i) {
                final d = _days[i];
                final sel = fmtDate(d) == dateStr;
                final showMonth = i == 0 || d.month != _days[i - 1].month;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selected = d;
                    _sel = const SlotSelection.empty();
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
                        if (showMonth)
                          Text(
                            '${monthLabel(d)} ${d.year}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white70
                                  : DeofootTheme.textMuted,
                            ),
                          ),
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
                SizedBox(width: 12),
                _Legend(color: DeofootTheme.booked, label: 'Terisi'),
                SizedBox(width: 12),
                _Legend(color: DeofootTheme.pending, label: 'Menunggu'),
                SizedBox(width: 12),
                _Legend(color: DeofootTheme.pastSlot, label: 'Lewat'),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tap slot hijau untuk pilih, tap lagi untuk batal. Seleksi selalu berurutan.',
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
                final now = DateTime.now();
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
                    final past =
                        isPastSlot(_selected, h, now) && st == SlotStatus.free;
                    final enabled = st == SlotStatus.free && !past;
                    final sel = _sel.contains(h);
                    Color bg;
                    Color fg = Colors.white;
                    if (sel) {
                      // Seleksi: navy + teks putih + centang (beda dari status).
                      bg = DeofootTheme.primary;
                    } else if (past) {
                      // Slot lewat: disabled, style sendiri (bukan abu Terisi).
                      bg = DeofootTheme.pastSlot;
                      fg = DeofootTheme.textMuted;
                    } else {
                      switch (st) {
                        case SlotStatus.free:
                          bg = DeofootTheme.available;
                          break;
                        case SlotStatus.booked:
                          bg = DeofootTheme.booked;
                          fg = DeofootTheme.textMuted;
                          break;
                        case SlotStatus.pending:
                          // Amber HANYA untuk "Menunggu verifikasi".
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
                      child: sel
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  hourLabel(h),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            )
                          : Text(
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
      bottomNavigationBar: _sel.isEmpty
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
                        startHour: _sel.start!,
                        endHour: _sel.end!,
                      ),
                    ),
                  ),
                  child: Text(
                      'Lanjut — ${_sel.hours} jam (${fmtRupiah(bookingTotal(_sel.hours, widget.field.pricePerHour))})'),
                ),
              ),
            ),
    );
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
