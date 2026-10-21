import 'package:flutter/material.dart';

import '../availability_logic.dart';
import '../booking_logic.dart';
import '../calendar_logic.dart';
import '../field_logic.dart';
import '../models.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/calendar_sheet.dart';
import '../widgets/pitch_components.dart';
import 'schedule_screen.dart';

/// Layar Cari Slot Kosong (Fase D v0.4, rework T8): user memilih
/// satu tanggal, satu jam mulai, durasi 1–4 jam, dan kategori
/// (opsional) → hasil = daftar LAPANGAN yang seluruh slot pada
/// rentang itu bebas (spek D2/D3/D6). Ketuk hasil → Jadwal
/// lapangan itu pada tanggal terpilih (D4).
/// (Fase G §3.4: tanggal lewat kalender yang sama dengan Jadwal,
/// durasi & kategori sebagai chip Pitch, hasil kartu Pitch masuk
/// berjenjang, dan Jadwal dibuka dengan slot hasil sudah
/// terpraseleksi. Logika pencarian tidak berubah.)
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

  void _setJamMulai(int h) {
    setState(() {
      _jamMulai = h;
      // Durasi tidak boleh menembus tutup grid global (22.00).
      if (_jamMulai + _durasi > closeHour) _durasi = closeHour - _jamMulai;
    });
  }

  void _openCalendar(List<Field> fields) {
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
              // Penanda untuk konteks pencarian: ada titik bila
              // MASIH ADA lapangan bebas pada rentang terpilih
              // (jam mulai + durasi saat ini) di tanggal itu.
              final aktif = fields.where((f) => f.isActive).toList();
              for (final d in days) {
                final ds = fmtDate(d);
                final todays = snap.data!
                    .where((b) => b.date == ds)
                    .toList();
                final bebas = !isPastSlot(d, _jamMulai, now) &&
                    lapanganBebas(
                      fields: aktif,
                      bookings: todays,
                      tanggal: ds,
                      jamMulai: _jamMulai,
                      durasiJam: _durasi,
                    ).isNotEmpty;
                marks[ds] = bebas ? DayMark.hasFree : DayMark.full;
              }
            }
            return CalendarSheet(
              days: days,
              selected: _selected,
              today: now,
              marks: marks,
              marksLoaded: snap.hasData,
              onSelect: (d) => setState(() => _selected = d),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final dateStr = fmtDate(_selected);
    return Scaffold(
      appBar: AppBar(title: const Text('Cari Slot Kosong')),
      body: StreamBuilder<List<Field>>(
        stream: fs.watchFields(),
        builder: (context, snapF) {
          final allFields = snapF.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Field tanggal -> kalender yang sama (§3.4).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: PitchCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  onTap: () => _openCalendar(allFields),
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
              // Filter: kategori (opsional, bawaan Semua — D2)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    for (final k in _kategori)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: PitchChip(
                          label: k,
                          selected: _kat == k,
                          onTap: () => setState(() => _kat = k),
                        ),
                      ),
                  ],
                ),
              ),
              // Filter: satu jam mulai + durasi 1–4 jam (D2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text('Jam mulai:', style: DeofootTheme.bodyStyle),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _jamMulai,
                      items: [
                        for (var h = openHour; h < closeHour; h++)
                          DropdownMenuItem(
                            value: h,
                            child: Text(
                              hourLabel(h),
                              style: DeofootTheme.tabular(
                                DeofootTheme.bodyStyle,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (v) => _setJamMulai(v!),
                    ),
                    const SizedBox(width: 16),
                    Text('Durasi:', style: DeofootTheme.bodyStyle),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    for (final d in [1, 2, 3, 4])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PitchChip(
                          label: '$d jam',
                          selected: _durasi == d,
                          onTap: _jamMulai + d <= closeHour
                              ? () => setState(() => _durasi = d)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Rentang dicari: ${hourLabel(_jamMulai)} – ${hourLabel(_jamMulai + _durasi)}',
                  style: DeofootTheme.captionStyle.copyWith(fontSize: 12),
                ),
              ),
              const Divider(height: 1),
              // Hasil: daftar lapangan bebas pada rentang itu (D3)
              Expanded(
                child: StreamBuilder<List<Booking>>(
                  stream: fs.watchBookingsByDate(dateStr),
                  builder: (context, snapB) {
                    if (snapF.connectionState == ConnectionState.waiting ||
                        snapB.connectionState == ConnectionState.waiting) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          PitchSkeletonCard(),
                          SizedBox(height: 16),
                          PitchSkeletonCard(),
                        ],
                      );
                    }
                    var fields = allFields;
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
                        for (var i = 0; i < hasil.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PitchEntrance(
                              key: ValueKey('search-${hasil[i].id}'),
                              id: 'search-${hasil[i].id}',
                              index: i,
                              child: PitchCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ScheduleScreen(
                                      field: hasil[i],
                                      initialDate: _selected,
                                      initialStartHour: _jamMulai,
                                      initialDuration: _durasi,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: hasil[i].color,
                                      child: Text(
                                        inisialNama(hasil[i].name),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hasil[i].name,
                                            style: DeofootTheme.bodyStyle
                                                .copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${hasil[i].category} • ${fmtRupiah(hasil[i].pricePerHour)}/jam',
                                            style: DeofootTheme.captionStyle
                                                .copyWith(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: DeofootTheme.ink60,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
