import 'package:flutter/material.dart';

import '../booking_logic.dart';
import '../field_logic.dart';
import '../models.dart';
import '../motion.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/pitch_components.dart';
import 'schedule_screen.dart';
import 'slot_search_screen.dart';

/// Layar 3 — Beranda (Fase G §3.2): sapaan + tanggal (Display),
/// kategori chip baris geser dengan indikator gelincir, kartu
/// lapangan Pitch (foto dominan radius 20, nama Title, harga
/// tabular tebal di kanan bawah), masuk berjenjang hanya pada
/// pemuatan pertama, dan skeleton shimmer saat memuat.
/// Fungsi tidak berubah dari v0.4.1.
class HomeScreen extends StatefulWidget {
  final String userEmail;
  final FirestoreService firestoreService;

  HomeScreen({
    super.key,
    required this.userEmail,
    FirestoreService? firestoreService,
  }) : firestoreService = firestoreService ?? FirestoreService();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _categories = ['Semua', 'Futsal', 'Padel', 'Tenis', 'Mini Soccer'];

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _tanggalId(DateTime d) =>
    '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';

class _HomeScreenState extends State<HomeScreen> {
  String _tab = 'Semua';
  final _chipKeys = [for (var i = 0; i < _categories.length; i++) GlobalKey()];
  final _rowKey = GlobalKey();
  List<double>? _chipCenters; // pusat-x tiap chip, relatif ke baris

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureChips());
  }

  void _measureChips() {
    final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (rowBox == null || !mounted) return;
    final centers = <double>[];
    for (final key in _chipKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: rowBox);
      centers.add(topLeft.dx + box.size.width / 2);
    }
    setState(() => _chipCenters = centers);
  }

  Widget _categoryRow() {
    final selectedIndex = _categories.indexOf(_tab);
    final centers = _chipCenters;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        key: _rowKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < _categories.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PitchChip(
                    key: _chipKeys[i],
                    label: _categories[i],
                    selected: _tab == _categories[i],
                    onTap: () => setState(() => _tab = _categories[i]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Indikator gelincir di bawah chip terpilih (transform).
          SizedBox(
            height: 3,
            child: Stack(
              children: [
                if (centers != null)
                  AnimatedContainer(
                    duration: PitchMotion.control,
                    curve: PitchMotion.easeInOut,
                    transform: Matrix4.translationValues(
                      centers[selectedIndex] - 12,
                      0,
                      0,
                    ),
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      color: DeofootTheme.pitch700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = widget.firestoreService;
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
              MaterialPageRoute(
                builder: (_) =>
                    SlotSearchScreen(firestoreService: widget.firestoreService),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Field>>(
        stream: fs.watchFields(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            // Skeleton berbentuk kartu — bukan spinner (§3.2).
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                PitchSkeletonCard(),
                SizedBox(height: 16),
                PitchSkeletonCard(),
                SizedBox(height: 16),
                PitchSkeletonCard(),
              ],
            );
          }
          final fields = snap.data ?? [];
          if (fields.isEmpty) {
            return const Center(child: Text('Data lapangan belum tersedia.'));
          }
          // Lapangan nonaktif disembunyikan dari user (Fase C).
          final aktif = fields.where((f) => f.isActive).toList();
          final shown = _tab == 'Semua'
              ? aktif
              : aktif.where((f) => f.category == _tab).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'Halo, ${widget.userEmail.split('@').first}!',
                style: DeofootTheme.displayStyle,
              ),
              const SizedBox(height: 4),
              Text(
                _tanggalId(DateTime.now()),
                style: DeofootTheme.bodyStyle.copyWith(
                  color: DeofootTheme.ink60,
                ),
              ),
              const SizedBox(height: 16),
              _categoryRow(),
              const SizedBox(height: 16),
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
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PitchEntrance(
                    key: ValueKey('field-${shown[i].id}'),
                    id: 'field-${shown[i].id}',
                    index: i,
                    child: _FieldCard(
                      field: shown[i],
                      date: today,
                      firestoreService: widget.firestoreService,
                    ),
                  ),
                ),
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
  final FirestoreService firestoreService;

  const _FieldCard({
    required this.field,
    required this.date,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    final fs = firestoreService;
    return PitchCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ScheduleScreen(field: field, firestoreService: firestoreService),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DeofootTheme.radiusCard),
            ),
            child: SizedBox(
              height: 150,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      field.photoAsset,
                      fit: BoxFit.cover,
                      // Placeholder spek C2: warna identitas lapangan
                      // + inisial namanya (bukan ikon).
                      errorBuilder: (_, _, _) => Container(
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
                  ),
                  // Badge kategori kecil.
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: field.color,
                        borderRadius: BorderRadius.circular(999),
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
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.name, style: DeofootTheme.titleStyle),
                const SizedBox(height: 8),
                Row(
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
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: DeofootTheme.pitch700.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$free slot bebas hari ini',
                            style: const TextStyle(
                              fontSize: 12,
                              color: DeofootTheme.pitch700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    // Harga: Body tebal tabular, kanan bawah (§3.2).
                    Text(
                      '${fmtRupiah(field.pricePerHour)}/jam',
                      style: DeofootTheme.tabular(
                        DeofootTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DeofootTheme.pitch700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
