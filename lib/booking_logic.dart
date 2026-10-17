import 'models.dart';

/// Port logika anti double-booking dari booking.py (cek_bentrok).
///
/// Aturan:
/// - overlap = m1 < s2 && m2 < s1 (dalam menit)
/// - status 'cancelled'/'rejected' diabaikan (slot dianggap bebas)
/// - tepi bersentuhan (end == start) BUKAN konflik
bool isOverlapping(int m1, int s1, int m2, int s2) => m1 < s2 && m2 < s1;

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
    if (b.status == 'cancelled' || b.status == 'rejected') continue;
    if (isOverlapping(startMin, endMin, b.startMinutes, b.endMinutes)) {
      return true;
    }
  }
  return false;
}

/// Status slot untuk grid jadwal.
enum SlotStatus { free, booked, pending }

/// Tentukan status tiap slot 60 menit dari daftar booking.
/// pending & confirmed → terisi; cancelled/rejected → bebas.
Map<int, SlotStatus> slotStatuses(
  List<Booking> bookings,
  String fieldId,
  String date,
) {
  final map = <int, SlotStatus>{};
  for (var h = 8; h < 22; h++) {
    map[h] = SlotStatus.free;
  }
  for (final b in bookings) {
    if (b.fieldId != fieldId || b.date != date) continue;
    if (b.status == 'cancelled' || b.status == 'rejected') continue;
    final h = b.startMinutes ~/ 60;
    if (map.containsKey(h)) {
      map[h] = b.status == 'pending' ? SlotStatus.pending : SlotStatus.booked;
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
