import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../field_logic.dart';
import '../services/firestore_service.dart';
import 'schedule_screen.dart';
import 'slot_search_screen.dart';

/// Layar 3 — Beranda: sapaan + tab kategori + kartu lapangan berfoto.
class HomeScreen extends StatefulWidget {
  final String userEmail;
  const HomeScreen({super.key, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _categories = ['Semua', 'Futsal', 'Padel', 'Tenis', 'Mini Soccer'];

class _HomeScreenState extends State<HomeScreen> {
  String _tab = 'Semua';

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final today = fmtDate(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/deofoot-logo.png', width: 32, height: 32),
            const SizedBox(width: 8),
            const Text('Deofoot'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari slot kosong',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SlotSearchScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Field>>(
        stream: fs.watchFields(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fields = snap.data ?? [];
          if (fields.isEmpty) {
            return const Center(
              child: Text('Data lapangan belum tersedia.'),
            );
          }
          // Lapangan nonaktif disembunyikan dari user (Fase C).
          final aktif = fields.where((f) => f.isActive).toList();
          final shown = _tab == 'Semua'
              ? aktif
              : aktif.where((f) => f.category == _tab).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Halo, ${widget.userEmail.split('@').first}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: DeofootTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih lapangan untuk booking.',
                style: TextStyle(color: DeofootTheme.textMuted),
              ),
              const SizedBox(height: 12),
              // Tab kategori
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in _categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: _tab == c,
                          onSelected: (_) => setState(() => _tab = c),
                          selectedColor: DeofootTheme.primary,
                          labelStyle: TextStyle(
                            color: _tab == c
                                ? Colors.white
                                : DeofootTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Belum ada lapangan di kategori ini.',
                      style: TextStyle(color: DeofootTheme.textMuted),
                    ),
                  ),
                ),
              for (final f in shown) _FieldCard(field: f, date: today),
            ],
          );
        },
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final Field field;
  final String date;
  const _FieldCard({required this.field, required this.date});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ScheduleScreen(field: field),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                // Foto lapangan (fallback bila file belum ada).
                Image.asset(
                  field.photoAsset,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Placeholder spek C2 (rework T17): warna identitas
                  // lapangan + inisial namanya (bukan ikon).
                  errorBuilder: (_, _, _) => Container(
                    height: 140,
                    color: field.color,
                    child: Center(
                      child: Text(
                        inisialNama(field.name),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Overlay gradient navy.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          DeofootTheme.primary.withValues(alpha: 0.78),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Badge kategori (aksen warna identitas lapangan).
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: field.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      field.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Nama + harga di atas foto.
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          field.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '${fmtRupiah(field.pricePerHour)}/jam',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  StreamBuilder<List<Booking>>(
                    stream: fs.watchBookings(field.id, date),
                    builder: (context, snap) {
                      final bookings = snap.data ?? [];
                      final statuses = slotStatuses(bookings, field.id, date);
                      final free = statuses.values
                          .where((s) => s == SlotStatus.free)
                          .length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: DeofootTheme.available.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$free slot bebas hari ini',
                          style: const TextStyle(
                            fontSize: 12,
                            color: DeofootTheme.available,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: DeofootTheme.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
