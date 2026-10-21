import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

/// Layar 5 — Booking 4 langkah: ringkasan → WA → bayar → bukti transfer.
/// Mendukung slot berurutan multi-jam dalam 1 transaksi.
class BookingScreen extends StatefulWidget {
  final Field field;
  final DateTime date;
  final int startHour;
  final int endHour; // eksklusif
  const BookingScreen({
    super.key,
    required this.field,
    required this.date,
    required this.startHour,
    required this.endHour,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _auth = AuthService();
  final _picker = ImagePicker();
  final _waCtrl = TextEditingController();
  XFile? _proof;
  bool _sending = false;
  int _payMethod = 0; // 0 DANA, 1 Transfer Bank, 2 E-Wallet lain
  Map<String, String>? _payConfig;

  static const _payMethods = [
    ('DANA', 'Kirim via aplikasi DANA ke nomor di bawah.'),
    ('Transfer Bank', 'Transfer via m-banking / ATM ke nomor DANA di bawah.'),
    ('E-Wallet lain', 'Kirim via OVO / GoPay / dll ke nomor DANA di bawah.'),
  ];

  int get _hours => widget.endHour - widget.startHour;
  int get _total => bookingTotal(_hours, widget.field.pricePerHour);

  @override
  void initState() {
    super.initState();
    _fs.getPaymentConfig().then((c) {
      if (mounted) setState(() => _payConfig = c);
    });
  }

  @override
  void dispose() {
    _waCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    // Kompresi di HP: ±800px, JPEG ±100KB (tanpa package tambahan).
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
      await _fs.createBooking(
        userId: u.uid,
        userEmail: u.email ?? '',
        fieldId: widget.field.id,
        fieldName: widget.field.name,
        date: fmtDate(widget.date),
        startHour: widget.startHour,
        endHour: widget.endHour,
        whatsapp: _waCtrl.text.trim(),
        proofBase64: b64,
        totalPrice: _total,
        pricePerHour: widget.field.pricePerHour,
      );
      // Izin notifikasi diminta pada momen ini — sesudah booking
      // pertama dibuat (spek A4, rework T2) — lalu jadwalkan pengingat.
      await NotificationService().mintaIzin();
      NotificationService().rekonsiliasiUntukUser(u.uid);
      if (!mounted) return;
      // Kembali ke Beranda + snackbar sukses.
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking terkirim, menunggu verifikasi.'),
          backgroundColor: DeofootTheme.available,
        ),
      );
    } on BookingConflictException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message),
              backgroundColor: DeofootTheme.danger),
        );
        Navigator.of(context).pop(); // kembali ke jadwal
      }
    } catch (e) {
      debugPrint('BookingScreen._send gagal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Gagal mengirim booking. Periksa koneksi lalu coba lagi.'),
              backgroundColor: DeofootTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = fmtDate(widget.date);
    final danaNumber = _payConfig?['danaNumber'] ?? '...';
    final danaName = _payConfig?['danaName'] ?? '...';
    final method = _payMethods[_payMethod];
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Lapangan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Langkah 1 — Ringkasan
              _stepTitle('1', 'Ringkasan booking'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Lapangan', widget.field.name),
                      _row('Tanggal', dateStr),
                      _row('Jam',
                          '${hourLabel(widget.startHour)} – ${hourLabel(widget.endHour)}'),
                      _row('Durasi', '${_hours * 60} menit'),
                      const Divider(),
                      _row('Total', fmtRupiah(_total), bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Langkah 2 — Nomor WhatsApp (wajib)
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
              // Langkah 3 — Pembayaran (3 metode, tanpa QRIS)
              _stepTitle('3', 'Pembayaran'),
              Card(
                child: RadioGroup<int>(
                  groupValue: _payMethod,
                  onChanged: (v) => setState(() => _payMethod = v!),
                  child: Column(
                    children: [
                      for (var i = 0; i < _payMethods.length; i++)
                        RadioListTile<int>(
                          value: i,
                          title: Text(_payMethods[i].$1,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(_payMethods[i].$2),
                        ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tujuan (${method.$1}):',
                          style: const TextStyle(
                              color: DeofootTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text('Nomor DANA: $danaNumber',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: DeofootTheme.primary)),
                      Text('a.n. $danaName',
                          style: const TextStyle(
                              color: DeofootTheme.textMuted)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: danaNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Nomor DANA disalin.')),
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
              // Langkah 4 — Bukti transfer
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
                            border: Border.all(
                                color: DeofootTheme.booked),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada bukti transfer',
                              style: TextStyle(
                                  color: DeofootTheme.textMuted),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickSheet,
                        icon:
                            const Icon(Icons.upload_outlined),
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
                // Tombol AKTIF hanya jika bukti sudah dipilih.
                onPressed:
                    (_proof == null || _sending) ? null : _send,
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Kirim Booking'),
              ),
              if (_proof == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Pilih bukti transfer dulu untuk mengaktifkan tombol.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: DeofootTheme.textMuted),
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
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text(t,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DeofootTheme.primary)),
          ],
        ),
      );

  Widget _row(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style:
                    const TextStyle(color: DeofootTheme.textMuted)),
            Text(v,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.w600,
                    color: DeofootTheme.primary)),
          ],
        ),
      );
}
