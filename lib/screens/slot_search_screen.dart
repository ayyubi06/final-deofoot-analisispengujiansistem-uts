import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../field_logic.dart';
import '../availability_logic.dart';
import '../services/firestore_service.dart';
import 'schedule_screen.dart';

/// Layar Cari Slot Kosong (Fase D v0.4, rework T8): user memilih satu
/// tanggal, satu jam mulai, durasi 1–4 jam, dan kategori (opsional) →
/// hasil = daftar LAPANGAN yang seluruh slot pada rentang itu bebas
/// (spek D2/D3/D6). Ketuk hasil → Jadwal lapangan itu pada tanggal
/// terpilih (D4).
class SlotSearchScreen extends StatefulWidget {
  const SlotSearchScreen({super.key});

  @override
  State<SlotSearchScreen> createState() => _SlotSearchScreenState();
}

const _kategori = ['Semua', 'Futsal', 'Padel', 'Tenis', 'Mini Soccer'];

class _SlotSearchScreenState extends State<SlotSearchScreen> {
  DateTime _selected = DateTime.now();
  int _jamMulai = 19;
  int _durasi = 1;
  String _kat = 'Semua';

  List<DateTime> get _days => bookingDateRange(DateTime.now());

  void _setJamMulai(int h) {
    setState(() {
      _jamMulai = h;
      // Durasi tidak boleh menembus tutup grid global (22.00).
      if (_jamMulai + _durasi > closeHour) _durasi = closeHour - _jamMulai;
    });
  }

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
          // Filter: kategori (opsional, bawaan Semua — D2)
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
          // Filter: satu jam mulai + durasi 1–4 jam (D2)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Text('Jam mulai:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _jamMulai,
                  items: [
                    for (var h = openHour; h < closeHour; h++)
                      DropdownMenuItem(value: h, child: Text(hourLabel(h))),
                  ],
                  onChanged: (v) => _setJamMulai(v!),
                ),
                const SizedBox(width: 16),
                const Text('Durasi:'),
                const SizedBox(width: 8),
                for (final d in [1, 2, 3, 4])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$d jam'),
                      selected: _durasi == d,
                      onSelected: _jamMulai + d <= closeHour
                          ? (_) => setState(() => _durasi = d)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Rentang dicari: ${hourLabel(_jamMulai)} – ${hourLabel(_jamMulai + _durasi)}',
              style: const TextStyle(
                  fontSize: 12, color: DeofootTheme.textMuted),
            ),
          ),
          const Divider(height: 1),
          // Hasil: daftar lapangan bebas pada rentang itu (D3)
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
                    // Slot yang sudah lewat (hari ini) tidak ditawarkan —
                    // konsisten dengan grid Jadwal.
                    final now = DateTime.now();
                    final sudahLewat = isPastSlot(_selected, _jamMulai, now);
                    final hasil = sudahLewat
                        ? const <Field>[]
                        : lapanganBebas(
                            fields: fields,
                            bookings: snapB.data ?? [],
                            tanggal: dateStr,
                            jamMulai: _jamMulai,
                            durasiJam: _durasi,
                          );
                    if (hasil.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            // Kalimat keadaan kosong spek D5 persis.
                            'Tidak ada lapangan bebas pada jam itu — coba geser jam atau tanggal.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: DeofootTheme.textMuted),
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final f in hasil)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: f.color,
                                child: Text(
                                  inisialNama(f.name),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                              title: Text(f.name),
                              subtitle: Text(
                                  '${f.category} • ${fmtRupiah(f.pricePerHour)}/jam'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ScheduleScreen(
                                    field: f,
                                    initialDate: _selected,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
