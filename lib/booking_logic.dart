import 'dart:math';
import 'models.dart';

/// Port logika anti double-booking dari booking.py (cek_bentrok).
///
/// Aturan:
/// - overlap = m1 < s2 && m2 < s1 (dalam menit)
/// - status 'cancelled'/'rejected' diabaikan (slot dianggap bebas)
/// - tepi bersentuhan (end == start) BUKAN konflik
bool isOverlapping(int m1, int s1, int m2, int s2) => m1 < s2 && m2 < s1;

/// Status yang membuat slot dianggap bebas / diabaikan.
bool _isIgnored(String s) =>
    s == 'cancelled' || s == 'rejected' || s == 'expired';

/// true jika slot (fieldId, date, [startMin, endMin)) bentrok dengan
/// booking AKTIF (pending/confirmed) lain.
bool hasConflict(
  List<Booking> bookings,
  String fieldId,
  String date,
  int startMin,
  int endMin,
) {
  for (final b in bookings) {
    if (b.fieldId != fieldId || b.date != date) continue;
    if (_isIgnored(b.status)) continue;
    if (isOverlapping(startMin, endMin, b.startMinutes, b.endMinutes)) {
      return true;
    }
  }
  return false;
}

/// Status slot untuk grid jadwal.
enum SlotStatus { free, booked, pending }

/// Tentukan status tiap slot 60 menit dari daftar booking.
/// pending & confirmed → terisi; cancelled/rejected/expired → bebas.
/// Rentang jam mengikuti grid lapangan (Fase C); bawaan 08–22 seperti
/// perilaku lama untuk dokumen tanpa scheduleGrid.
Map<int, SlotStatus> slotStatuses(
  List<Booking> bookings,
  String fieldId,
  String date, {
  int openHour = 8,
  int closeHour = 22,
}) {
  final map = <int, SlotStatus>{};
  for (var h = openHour; h < closeHour; h++) {
    map[h] = SlotStatus.free;
  }
  for (final b in bookings) {
    if (b.fieldId != fieldId || b.date != date) continue;
    if (_isIgnored(b.status)) continue;
    // Booking bisa multi-jam: tandai SEMUA jam dalam rentang.
    final h0 = b.startMinutes ~/ 60;
    final h1 = (b.endMinutes - 1) ~/ 60;
    for (var h = h0; h <= h1; h++) {
      if (map.containsKey(h)) {
        map[h] = b.status == 'pending' ? SlotStatus.pending : SlotStatus.booked;
      }
    }
  }
  return map;
}

/// Format "HH:mm" dari jam integer.
String hourLabel(int h) => '${h.toString().padLeft(2, '0')}.00';

/// Format tanggal "yyyy-MM-dd".
String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Label hari Indonesia singkat.
String dayLabel(DateTime d) {
  const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  // DateTime.weekday: 1=Senin .. 7=Minggu
  return days[d.weekday % 7];
}

/// Format Rupiah: 120000 -> "Rp120.000".
String fmtRupiah(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp${buf.toString()}';
}

/// Validasi nomor WhatsApp: diawali 08, semua digit, total 10-14 digit.
bool isValidWhatsapp(String v) {
  final t = v.trim();
  return RegExp(r'^08\d{8,12}$').hasMatch(t);
}

// ---------- v0.3: seleksi slot, tanggal, harga dinamis ----------

/// Seleksi slot: satu blok berurutan [start, end), atau kosong.
class SlotSelection {
  final int? start; // inklusif, null = tidak ada seleksi
  final int? end; // eksklusif
  const SlotSelection(this.start, this.end);
  const SlotSelection.empty() : this(null, null);

  bool get isEmpty => start == null;
  bool contains(int h) => !isEmpty && h >= start! && h < end!;
  int get hours => isEmpty ? 0 : end! - start!;
}

/// Aturan toggle tap slot (murni, bisa di-test).
/// [selectable] true bila slot boleh dipilih (bebas & belum lewat).
/// - slot tak bisa dipilih → seleksi tidak berubah
/// - tap slot yang sedang terpilih → batal (kosong)
/// - belum ada seleksi → pilih 1 jam
/// - tap slot bebas bersebelahan → perluas blok
/// - tap slot bebas tak bersebelahan (terhalang) → mulai seleksi baru
SlotSelection toggleSlot(
    SlotSelection sel, int h, bool Function(int) selectable) {
  if (!selectable(h)) return sel;
  if (!sel.isEmpty && sel.contains(h)) return const SlotSelection.empty();
  if (sel.isEmpty) return SlotSelection(h, h + 1);
  final ns = min(sel.start!, h);
  final ne = max(sel.end!, h + 1);
  for (var hh = ns; hh < ne; hh++) {
    if (!selectable(hh)) return SlotSelection(h, h + 1);
  }
  return SlotSelection(ns, ne);
}

/// Rentang tanggal booking: hari ini → H+59 (60 hari).
List<DateTime> bookingDateRange(DateTime now) {
  final base = DateTime(now.year, now.month, now.day);
  return List.generate(60, (i) => base.add(Duration(days: i)));
}

/// true bila slot [hour] pada tanggal [selected] sudah lewat.
/// Hanya berlaku untuk hari ini; tanggal lain selalu false.
bool isPastSlot(DateTime selected, int hour, DateTime now) {
  if (fmtDate(selected) != fmtDate(now)) return false;
  return hour <= now.hour;
}

/// Label bulan Indonesia singkat.
String monthLabel(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  return m[d.month - 1];
}

/// Total harga booking: jam × tarif lapangan (tarif dari Firestore,
/// bukan hardcode).
int bookingTotal(int hours, int pricePerHour) => hours * pricePerHour;
