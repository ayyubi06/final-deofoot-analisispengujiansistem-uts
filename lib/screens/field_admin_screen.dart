import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../field_logic.dart';
import '../services/firestore_service.dart';

/// Layar Kelola Lapangan (admin, Fase C v0.4): daftar semua lapangan
/// (termasuk nonaktif), tambah, ubah (nama, kategori, harga, warna,
/// jam operasional), dan aktif/nonaktifkan. Lapangan TIDAK dihapus
/// permanen dari aplikasi — nonaktifkan adalah penggantinya.
class FieldAdminScreen extends StatelessWidget {
  const FieldAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Lapangan')),
      body: StreamBuilder<List<Field>>(
        stream: fs.watchFields(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
            itemBuilder: (_, i) => _FieldAdminCard(field: fields[i]),
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
  const _FieldAdminCard({required this.field});

  @override
  Widget build(BuildContext context) {
    final f = field;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: f.color,
          child: const Icon(Icons.sports_soccer, color: Colors.white),
        ),
        title: Text(f.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${f.category} • ${fmtRupiah(f.pricePerHour)}/jam • '
          '${hourLabel(f.openHour)}–${hourLabel(f.closeHour)}'
          '${f.isActive ? '' : ' • NONAKTIF'}',
        ),
        trailing: Switch(
          value: f.isActive,
          onChanged: (v) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await FirestoreService().setFieldActive(f.id, v);
              messenger.showSnackBar(SnackBar(
                content: Text(v
                    ? '${f.name} diaktifkan.'
                    : '${f.name} dinonaktifkan (disembunyikan dari user).'),
              ));
            } catch (e) {
              debugPrint('FieldAdmin setFieldActive gagal: $e');
              messenger.showSnackBar(const SnackBar(
                content: Text('Gagal mengubah status. Coba lagi.'),
                backgroundColor: DeofootTheme.danger,
              ));
            }
          },
        ),
        onTap: () async {
          final fields = await FirestoreService().watchFields().first;
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FieldFormScreen(
                existing: f,
                existingIds: fields.map((x) => x.id).toSet(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Form tambah/ubah lapangan.
class FieldFormScreen extends StatefulWidget {
  final Field? existing;
  final Set<String> existingIds;
  const FieldFormScreen({super.key, this.existing, required this.existingIds});

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
  late int _openHour;
  late int _closeHour;
  late bool _aktif;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _namaCtrl = TextEditingController(text: e?.name ?? '');
    _hargaCtrl =
        TextEditingController(text: e == null ? '' : '${e.pricePerHour}');
    _kategoriSel = e?.category ?? 'Futsal';
    _warnaArgb = e?.color.toARGB32() ?? 0xFF102A43;
    _openHour = e?.openHour ?? 8;
    _closeHour = e?.closeHour ?? 22;
    _aktif = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final err = validasiField(
      nama: _namaCtrl.text,
      hargaTeks: _hargaCtrl.text,
      openHour: _openHour,
      closeHour: _closeHour,
    );
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
      openHour: _openHour,
      closeHour: _closeHour,
    );
    try {
      if (e == null) {
        await FirestoreService().createField(f);
      } else {
        await FirestoreService().updateField(f);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e == null
                ? 'Lapangan ditambahkan.'
                : 'Lapangan disimpan.')),
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
      appBar: AppBar(
          title: Text(isNew ? 'Tambah Lapangan' : 'Ubah Lapangan')),
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
              children: [
                for (final (namaWarna, argb) in _warnaPreset)
                  ChoiceChip(
                    label: Text(namaWarna),
                    avatar: CircleAvatar(
                      backgroundColor: Color(argb),
                      radius: 8,
                    ),
                    selected: _warnaArgb == argb,
                    onSelected: (_) => setState(() => _warnaArgb = argb),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Jam buka'),
                      DropdownButton<int>(
                        value: _openHour,
                        isExpanded: true,
                        items: [
                          for (var h = 0; h < 24; h++)
                            DropdownMenuItem(
                                value: h, child: Text(hourLabel(h))),
                        ],
                        onChanged: (v) => setState(() => _openHour = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Jam tutup'),
                      DropdownButton<int>(
                        value: _closeHour,
                        isExpanded: true,
                        items: [
                          for (var h = 1; h <= 24; h++)
                            DropdownMenuItem(
                                value: h, child: Text(hourLabel(h))),
                        ],
                        onChanged: (v) => setState(() => _closeHour = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Lapangan aktif'),
              subtitle: const Text(
                  'Nonaktif = disembunyikan dari user & tidak bisa dibooking. Riwayat booking lama tetap utuh.'),
              value: _aktif,
              onChanged: (v) => setState(() => _aktif = v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Catatan foto: foto lapangan mengikuti id-nya '
              '(assets/images/fields/<id>.jpg). Lapangan baru tampil '
              'dengan ikon sampai aset fotonya ditambahkan ke aplikasi.',
              style: TextStyle(fontSize: 12, color: DeofootTheme.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _simpan,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: DeofootTheme.primary)),
      );
}
