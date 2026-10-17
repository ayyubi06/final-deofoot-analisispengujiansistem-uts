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

/// Layar 5 — Booking 3 langkah: ringkasan → bayar DANA → bukti transfer.
class BookingScreen extends StatefulWidget {
  final Field field;
  final DateTime date;
  final int startHour;
  const BookingScreen({
    super.key,
    required this.field,
    required this.date,
    required this.startHour,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _fs = FirestoreService();
  final _auth = AuthService();
  final _picker = ImagePicker();
  XFile? _proof;
  bool _sending = false;
  Map<String, String>? _payConfig;

  @override
  void initState() {
    super.initState();
    _fs.getPaymentConfig().then((c) {
      if (mounted) setState(() => _payConfig = c);
    });
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
        proofBase64: b64,
        totalPrice: widget.field.pricePerHour,
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal mengirim: $e'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Lapangan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                        '${hourLabel(widget.startHour)} – ${hourLabel(widget.startHour + 1)}'),
                    _row('Durasi', '60 menit'),
                    const Divider(),
                    _row('Total', fmtRupiah(widget.field.pricePerHour),
                        bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Langkah 2 — Bayar via DANA
            _stepTitle('2', 'Bayar via DANA'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            // Langkah 3 — Bukti transfer
            _stepTitle('3', 'Bukti transfer'),
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
