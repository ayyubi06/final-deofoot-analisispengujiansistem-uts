import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../recurring_logic.dart';
import '../report_logic.dart' show namaHari, tanggalIndonesia;
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

/// Layar Langganan Rutin (Fase E v0.4): booking slot yang sama setiap
/// minggu untuk N pertemuan, SATU bukti bayar untuk seluruh seri.
/// Seri dibuat all-or-nothing: satu tanggal bentrok → tidak jadi.
class RecurringScreen extends StatefulWidget {
  final Field field;
  final DateTime? initialDate;
  final int? initialStartHour;
  final int? initialDuration;
  const RecurringScreen({
    super.key,
    required this.field,
    this.initialDate,
    this.initialStartHour,
    this.initialDuration,
  });

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _auth = AuthService();
  final _picker = ImagePicker();
  final _waCtrl = TextEditingController();

  /// Hari terpilih (1=Senin .. 7=Minggu) — spek E2 (rework T13):
  /// user memilih HARI; tanggal pertemuan pertama diturunkan.
  late int _weekday;
  late int _startHour;
  late int _durasi;
  int _meetings = 4;
  XFile? _proof;
  bool _sending = false;
  Map<String, String>? _payConfig;

  /// Pertemuan pertama = kemunculan pertama hari terpilih mulai besok.
  DateTime get _startDate => tanggalPertamaUntukHari(_weekday, DateTime.now());
  List<String> get _dates => ekspansiTanggalSeri(_startDate, _meetings);
  int get _total => totalHargaSeri(
        jumlahPertemuan: _meetings,
        durasiJam: _durasi,
        pricePerHour: widget.field.pricePerHour,
      );

  @override
  void initState() {
    super.initState();
    // Hari awal: dari tanggal konteks Jadwal bila ada; selain itu
    // hari besok (agar pertemuan pertama = besok, sesuai bawaan E2).
    _weekday = widget.initialDate?.weekday ??
        DateTime.now().add(const Duration(days: 1)).weekday;
    _startHour = widget.initialStartHour ?? openHour;
    if (_startHour < openHour || _startHour >= closeHour) {
      _startHour = openHour;
    }
    _durasi = widget.initialDuration ?? 1;
    _clampDurasi();
    _fs.getPaymentConfig().then((c) {
      if (mounted) setState(() => _payConfig = c);
    });
  }

  @override
  void dispose() {
    _waCtrl.dispose();
    super.dispose();
  }

  void _clampDurasi() {
    final maxDur = closeHour - _startHour;
    if (_durasi > maxDur) _durasi = maxDur;
    if (_durasi < 1) _durasi = 1;
  }

  Future<void> _pick(ImageSource src) async {
    final f = await _picker.pickImage(
      source: src,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (f != null) setState(() => _proof = f);
  }

  void _pickSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil foto'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (_proof == null || _sending) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final bytes = await File(_proof!.path).readAsBytes();
      final b64 = base64Encode(bytes);
      final u = _auth.currentUser!;
      await _fs.createSeries(
        userId: u.uid,
        userEmail: u.email ?? '',
        fieldId: widget.field.id,
        fieldName: widget.field.name,
        meetingDates: _dates,
        startHour: _startHour,
        endHour: _startHour + _durasi,
        whatsapp: _waCtrl.text.trim(),
        proofBase64: b64,
        pricePerHour: widget.field.pricePerHour,
      );
      // Izin notifikasi diminta sesudah booking (pertama) dibuat —
      // spek A4 (rework T2); lalu rekonsiliasi pengingat seri (A/E9).
      await NotificationService().mintaIzin();
      NotificationService().rekonsiliasiUntukUser(u.uid);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Langganan terkirim, menunggu verifikasi.'),
          backgroundColor: DeofootTheme.available,
        ),
      );
    } on SeriesConflictException catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Slot sudah terisi'),
            content: Text(
              'Seri tidak dibuat (all-or-nothing). Tanggal yang bentrok:\n\n'
              '${e.tanggalKonflik.map((t) => '• ${tanggalIndonesia(DateTime.parse(t))}').join('\n')}\n\n'
              'Ubah jam/hari mulai atau kurangi jumlah pertemuan, lalu coba lagi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('RecurringScreen._send gagal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Gagal mengirim langganan. Periksa koneksi lalu coba lagi.'),
            backgroundColor: DeofootTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final danaNumber = _payConfig?['danaNumber'] ?? '...';
    final danaName = _payConfig?['danaName'] ?? '...';
    return Scaffold(
      appBar: AppBar(title: const Text('Langganan Rutin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepTitle('1', 'Atur seri mingguan'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Lapangan', f.name),
                      const SizedBox(height: 8),
                      const Text('Hari',
                          style: TextStyle(color: DeofootTheme.textMuted)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var wd = 1; wd <= 7; wd++)
                            ChoiceChip(
                              // 1 Jan 2024 = Senin (acuan nama hari).
                              label: Text(namaHari(DateTime(2024, 1, wd))),
                              selected: _weekday == wd,
                              onSelected: (_) =>
                                  setState(() => _weekday = wd),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _row('Pertemuan pertama',
                          tanggalIndonesia(_startDate)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Jam mulai',
                              style: TextStyle(color: DeofootTheme.textMuted)),
                          const Spacer(),
                          DropdownButton<int>(
                            value: _startHour,
                            items: [
                              for (var h = openHour; h < closeHour; h++)
                                DropdownMenuItem(
                                    value: h, child: Text(hourLabel(h))),
                            ],
                            onChanged: (v) => setState(() {
                              _startHour = v!;
                              _clampDurasi();
                            }),
                          ),
                          const SizedBox(width: 16),
                          const Text('Durasi',
                              style: TextStyle(color: DeofootTheme.textMuted)),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _durasi,
                            items: [
                              for (var d = 1;
                                  d <= closeHour - _startHour && d <= 4;
                                  d++)
                                DropdownMenuItem(
                                    value: d, child: Text('$d jam')),
                            ],
                            onChanged: (v) => setState(() => _durasi = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Pertemuan',
                              style: TextStyle(color: DeofootTheme.textMuted)),
                          const Spacer(),
                          for (final n in [4, 8, 12])
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: Text('$n×'),
                                selected: _meetings == n,
                                onSelected: (_) =>
                                    setState(() => _meetings = n),
                              ),
                            ),
                        ],
                      ),
                      const Divider(),
                      _row('Setiap',
                          '${namaHari(_startDate)} ${hourLabel(_startHour)}–${hourLabel(_startHour + _durasi)}'),
                      _row('Periode',
                          '${_dates.first} s/d ${_dates.last}'),
                      _row('Total ($_meetings pertemuan)',
                          fmtRupiah(_total),
                          bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _dates)
                    Chip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _stepTitle('2', 'Nomor WhatsApp'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _waCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp aktif',
                      hintText: '08xxxxxxxxxx',
                      prefixIcon: Icon(Icons.chat_outlined),
                    ),
                    validator: (v) => isValidWhatsapp(v ?? '')
                        ? null
                        : 'Nomor WA wajib diisi, format 08… (10–14 digit).',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _stepTitle('3', 'Pembayaran (satu kali untuk seluruh seri)'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tujuan (DANA):',
                          style: TextStyle(color: DeofootTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text('Nomor DANA: $danaNumber',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: DeofootTheme.primary)),
                      Text('a.n. $danaName',
                          style: const TextStyle(color: DeofootTheme.textMuted)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: danaNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nomor DANA disalin.')),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Salin nomor'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _stepTitle('4', 'Bukti transfer'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_proof != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_proof!.path),
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: DeofootTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DeofootTheme.booked),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada bukti transfer',
                              style: TextStyle(color: DeofootTheme.textMuted),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickSheet,
                        icon: const Icon(Icons.upload_outlined),
                        label: Text(_proof == null
                            ? 'Pilih bukti transfer'
                            : 'Ganti bukti transfer'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_proof == null || _sending) ? null : _send,
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Kirim Langganan'),
              ),
              if (_proof == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Pilih bukti transfer dulu untuk mengaktifkan tombol.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: DeofootTheme.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepTitle(String n, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: DeofootTheme.primary,
              child: Text(n,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: DeofootTheme.primary)),
            ),
          ],
        ),
      );

  Widget _row(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: DeofootTheme.textMuted)),
            Flexible(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                      color: DeofootTheme.primary)),
            ),
          ],
        ),
      );
}
