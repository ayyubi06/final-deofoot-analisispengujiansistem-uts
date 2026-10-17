import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../services/firestore_service.dart';
import 'booking_screen.dart';

/// Layar 4 — Jadwal lapangan: date picker 7 hari + grid slot 08.00–22.00.
class ScheduleScreen extends StatefulWidget {
  final Field field;
  const ScheduleScreen({super.key, required this.field});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selected = DateTime.now();

  List<DateTime> get _days =>
      List.generate(7, (i) => DateTime.now().add(Duration(days: i)));

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final dateStr = fmtDate(_selected);
    return Scaffold(
      appBar: AppBar(title: Text('Jadwal — Lapangan ${widget.field.name}')),
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
                  onTap: () => setState(() => _selected = d),
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
                    Color bg;
                    Color fg = Colors.white;
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
                    return ElevatedButton(
                      onPressed: enabled
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookingScreen(
                                    field: widget.field,
                                    date: _selected,
                                    startHour: h,
                                  ),
                                ),
                              )
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
