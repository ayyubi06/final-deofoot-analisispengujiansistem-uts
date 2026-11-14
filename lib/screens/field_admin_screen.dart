import 'package:flutter/material.dart';

import '../booking_logic.dart';
import '../field_logic.dart';
import '../models.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/pitch_components.dart';

/// Layar Kelola Lapangan (admin, Fase C v0.4): daftar semua lapangan
/// (termasuk nonaktif), tambah, ubah (nama, kategori, harga, warna),
/// dan aktif/nonaktifkan. Lapangan TIDAK dihapus permanen dari
/// aplikasi — nonaktifkan adalah penggantinya.
/// (Fase G §3.8: kartu Pitch, avatar radius 20, saklar pegas
/// PitchToggle, kartu nonaktif meredup di tempat, chip warna
/// bercincin volt saat terpilih.)
class FieldAdminScreen extends StatelessWidget {
  final FirestoreService firestoreService;

  FieldAdminScreen({super.key, FirestoreService? firestoreService})
    : firestoreService = firestoreService ?? FirestoreService();

  @override
  Widget build(BuildContext context) {
    final fs = firestoreService;
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Lapangan')),
      body: StreamBuilder<List<Field>>(
        stream: fs.watchFields(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                PitchSkeletonCard(),
                SizedBox(height: 16),
                PitchSkeletonCard(),
              ],
            );
          }
          final fields = snap.data ?? [];
          if (fields.isEmpty) {
            return const Center(
              child: Text('Belum ada lapangan. Tambah lewat tombol +.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: fields.length,
            itemBuilder: (_, i) => _FieldAdminCard(
              field: fields[i],
              firestoreService: firestoreService,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final fields = await fs.watchFields().first;
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FieldFormScreen(
                existingIds: fields.map((f) => f.id).toSet(),
                firestoreService: firestoreService,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}

class _FieldAdminCard extends StatelessWidget {
  final Field field;
  final FirestoreService firestoreService;

  const _FieldAdminCard({required this.field, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    final f = field;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PitchCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () async {
          final fields = await firestoreService.watchFields().first;
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FieldFormScreen(
                existing: f,
                existingIds: fields.map((x) => x.id).toSet(),
                firestoreService: firestoreService,
              ),
            ),
          );
        },
        child: Row(
          children: [
            // Identitas + nama meredup di tempat saat nonaktif (§3.8);
            // saklarnya sendiri tetap jelas & bisa diketuk.
            Expanded(
              child: AnimatedOpacity(
                opacity: f.isActive ? 1 : 0.55,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: f.color,
                        borderRadius: BorderRadius.circular(
                          DeofootTheme.radiusCard,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        inisialNama(f.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            style: DeofootTheme.bodyStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${f.category} • ${fmtRupiah(f.pricePerHour)}/jam'
                            '${f.isActive ? '' : ' • NONAKTIF'}',
                            style: DeofootTheme.captionStyle.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PitchToggle(
              value: f.isActive,
              onChanged: (v) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await firestoreService.setFieldActive(f.id, v);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        v
                            ? '${f.name} diaktifkan.'
                            : '${f.name} dinonaktifkan (disembunyikan dari user).',
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint('FieldAdmin setFieldActive gagal: $e');
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Gagal mengubah status. Coba lagi.'),
                      backgroundColor: DeofootTheme.danger,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Form tambah/ubah lapangan.
class FieldFormScreen extends StatefulWidget {
  final Field? existing;
  final Set<String> existingIds;
  final FirestoreService firestoreService;

  FieldFormScreen({
    super.key,
    this.existing,
    required this.existingIds,
    FirestoreService? firestoreService,
  }) : firestoreService = firestoreService ?? FirestoreService();

  @override
  State<FieldFormScreen> createState() => _FieldFormScreenState();
}

const _kategori = ['Futsal', 'Padel', 'Tenis', 'Mini Soccer'];
const _warnaPreset = <(String, int)>[
  ('Navy', 0xFF102A43),
  ('Oranye', 0xFFFF7A1A),
  ('Hijau', 0xFF16A34A),
  ('Biru', 0xFF2563EB),
  ('Ungu', 0xFF7C3AED),
  ('Pink', 0xFFDB2777),
  ('Teal', 0xFF0F766E),
  ('Merah', 0xFFDC2626),
];

class _FieldFormScreenState extends State<FieldFormScreen> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _hargaCtrl;
  late String _kategoriSel;
  late int _warnaArgb;
  late bool _aktif;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _namaCtrl = TextEditingController(text: e?.name ?? '');
    _hargaCtrl = TextEditingController(
      text: e == null ? '' : '${e.pricePerHour}',
    );
    _kategoriSel = e?.category ?? 'Futsal';
    _warnaArgb = e?.color.toARGB32() ?? 0xFF102A43;
    _aktif = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final err = validasiField(nama: _namaCtrl.text, hargaTeks: _hargaCtrl.text);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: DeofootTheme.danger),
      );
      return;
    }
    setState(() => _saving = true);
    final e = widget.existing;
    final f = Field(
      id: e?.id ?? fieldIdUnik(_namaCtrl.text, widget.existingIds),
      name: _namaCtrl.text.trim(),
      pricePerHour: parseHarga(_hargaCtrl.text),
      category: _kategoriSel,
      color: Color(_warnaArgb),
      isActive: _aktif,
    );
    try {
      if (e == null) {
        await widget.firestoreService.createField(f);
      } else {
        await widget.firestoreService.updateField(f);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e == null ? 'Lapangan ditambahkan.' : 'Lapangan disimpan.',
          ),
        ),
      );
    } catch (err2) {
      debugPrint('FieldFormScreen._simpan gagal: $err2');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan. Coba lagi.'),
            backgroundColor: DeofootTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Tambah Lapangan' : 'Ubah Lapangan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _namaCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama lapangan',
                hintText: 'mis. Lapangan Futsal 3',
              ),
            ),
            const SizedBox(height: 16),
            _label('Kategori'),
            DropdownButton<String>(
              value: _kategoriSel,
              isExpanded: true,
              items: [
                for (final k in _kategori)
                  DropdownMenuItem(value: k, child: Text(k)),
              ],
              onChanged: (v) => setState(() => _kategoriSel = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hargaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga per jam (Rp)',
                hintText: 'mis. 150000',
              ),
            ),
            const SizedBox(height: 16),
            _label('Warna identitas'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (namaWarna, argb) in _warnaPreset)
                  _ColorChip(
                    label: namaWarna,
                    color: Color(argb),
                    selected: _warnaArgb == argb,
                    onTap: () => setState(() => _warnaArgb = argb),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lapangan aktif',
                        style: DeofootTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Nonaktif = disembunyikan dari user & tidak bisa dibooking. Riwayat booking lama tetap utuh.',
                        style: TextStyle(
                          fontSize: 12,
                          color: DeofootTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PitchToggle(
                  value: _aktif,
                  onChanged: (v) => setState(() => _aktif = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Catatan foto: foto lapangan mengikuti id-nya '
              '(assets/images/fields/<id>.jpg). Lapangan baru tanpa '
              'aset foto tampil dengan placeholder warna identitas + '
              'inisial nama (spek C2).',
              style: TextStyle(fontSize: 12, color: DeofootTheme.textMuted),
            ),
            const SizedBox(height: 24),
            if (_saving) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  color: DeofootTheme.pitch700,
                  backgroundColor: DeofootTheme.line,
                ),
              ),
              const SizedBox(height: 12),
            ],
            PitchButton(
              label: _saving ? 'Menyimpan…' : 'Simpan',
              onPressed: _saving ? null : _simpan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      t,
      style: DeofootTheme.bodyStyle.copyWith(
        fontWeight: FontWeight.w600,
        color: DeofootTheme.pitch900,
      ),
    ),
  );
}

/// Chip warna form lapangan: contoh warna + nama; yang terpilih
/// mendapat CINCIN VOLT (§3.8).
class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? DeofootTheme.volt.withValues(alpha: 0.18)
              : DeofootTheme.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? DeofootTheme.volt : DeofootTheme.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(backgroundColor: color, radius: 8),
            const SizedBox(width: 8),
            Text(
              label,
              style: DeofootTheme.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: DeofootTheme.pitch900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
