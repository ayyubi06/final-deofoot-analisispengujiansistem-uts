import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../availability_logic.dart';
import '../services/firestore_service.dart';
import 'schedule_screen.dart';

/// Layar Cari Slot Kosong (Fase D v0.4): pilih tanggal, durasi, jendela
/// jam (dan kategori) → daftar slot kosong lintas lapangan, terurut jam
/// mulai. Ketuk hasil → masuk Jadwal lapangan pada tanggal itu.
class SlotSearchScreen extends StatefulWidget {
  const SlotSearchScreen({super.key});

  @override
  State<SlotSearchScreen> createState() => _SlotSearchScreenState();
}

const _kategori = ['Semua', 'Futsal', 'Padel', 'Tenis', 'Mini Soccer'];

class _SlotSearchScreenState extends State<SlotSearchScreen> {
  DateTime _selected = DateTime.now();
  int _durasi = 1;
  int _jamMulai = 8;
  int _jamSelesai = 22;
  String _kat = 'Semua';

  List<DateTime> get _days => bookingDateRange(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final dateStr = fmtDate(_selected);
    return Scaffold(
      appBar: AppBar(title: const Text('Cari Slot Kosong')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Strip tanggal 60 hari (pola sama dengan layar Jadwal).
          SizedBox(
            height: 88,
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
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: sel ? DeofootTheme.primary : DeofootTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? DeofootTheme.primary : DeofootTheme.booked,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel(d),
                          style: TextStyle(
                            fontSize: 12,
                            color: sel ? Colors.white70 : DeofootTheme.textMuted,
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: sel ? Colors.white : DeofootTheme.primary,
                          ),
                        ),
                        Text(
                          monthLabel(d),
                          style: TextStyle(
                            fontSize: 10,
                            color: sel ? Colors.white70 : DeofootTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Filter: kategori
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final k in _kategori)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(k),
                      selected: _kat == k,
                      onSelected: (_) => setState(() => _kat = k),
                      selectedColor: DeofootTheme.primary,
                      labelStyle: TextStyle(
                        color: _kat == k ? Colors.white : DeofootTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Filter: durasi + jendela jam
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Text('Durasi:'),
                const SizedBox(width: 8),
                for (final d in [1, 2, 3])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$d jam'),
                      selected: _durasi == d,
                      onSelected: (_) => setState(() => _durasi = d),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                const Text('Jam:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _jamMulai,
                  items: [
                    for (var h = 0; h < 24; h++)
                      DropdownMenuItem(value: h, child: Text(hourLabel(h))),
                  ],
                  onChanged: (v) => setState(() {
                    _jamMulai = v!;
                    if (_jamSelesai <= _jamMulai) {
                      _jamSelesai = _jamMulai + 1;
                    }
                  }),
                ),
                const Text(' – '),
                DropdownButton<int>(
                  value: _jamSelesai,
                  items: [
                    for (var h = 1; h <= 24; h++)
                      DropdownMenuItem(value: h, child: Text(hourLabel(h))),
                  ],
                  onChanged: (v) => setState(() {
                    _jamSelesai = v!;
                    if (_jamMulai >= _jamSelesai) {
                      _jamMulai = _jamSelesai - 1;
                    }
                  }),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Hasil
          Expanded(
            child: StreamBuilder<List<Field>>(
              stream: fs.watchFields(),
              builder: (context, snapF) {
                return StreamBuilder<List<Booking>>(
                  stream: fs.watchBookingsByDate(dateStr),
                  builder: (context, snapB) {
                    if (snapF.connectionState == ConnectionState.waiting ||
                        snapB.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var fields = snapF.data ?? [];
                    if (_kat != 'Semua') {
                      fields =
                          fields.where((f) => f.category == _kat).toList();
                    }
                    final perField = <String, List<Booking>>{};
                    for (final b in snapB.data ?? []) {
                      perField.putIfAbsent(b.fieldId, () => []).add(b);
                    }
                    final hasil = cariSlotKosong(
                      fields: fields,
                      bookingsPerField: perField,
                      tanggal: dateStr,
                      durasiJam: _durasi,
                      jamMulai: _jamMulai,
                      jamSelesai: _jamSelesai,
                      now: DateTime.now(),
                    );
                    if (hasil.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Tidak ada slot kosong yang cocok. Coba durasi lebih pendek atau jendela jam lain.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: DeofootTheme.textMuted),
                          ),
                        ),
                      );
                    }
                    // Kelompokkan per jam mulai.
                    final grup = <int, List<SlotKosong>>{};
                    for (final s in hasil) {
                      grup.putIfAbsent(s.startHour, () => []).add(s);
                    }
                    final jamUrut = grup.keys.toList()..sort();
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final jam in jamUrut) ...[
                          Text(
                            '${hourLabel(jam)} – ${hourLabel(grup[jam]!.first.endHour)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: DeofootTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final s in grup[jam]!)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: s.field.color,
                                  child: const Icon(Icons.sports_soccer,
                                      color: Colors.white, size: 20),
                                ),
                                title: Text(s.field.name),
                                subtitle: Text(
                                    '${s.field.category} • ${fmtRupiah(s.field.pricePerHour)}/jam'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ScheduleScreen(
                                      field: s.field,
                                      initialDate: _selected,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ],
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
}
