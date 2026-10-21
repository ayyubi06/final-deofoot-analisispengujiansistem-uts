import 'booking_logic.dart';
import 'models.dart';

/// Logika murni kalender Fase G §3.3 (G8): penanda ketersediaan
/// per tanggal. Murni & bisa di-test — tanpa UI/Firestore.

/// Penanda satu tanggal di kalender:
/// - [hasFree]: masih ada slot bebas -> titik volt.
/// - [full]: semua slot terisi/pending atau sudah lewat -> "Penuh".
/// - [unknown]: data belum tiba -> tanpa penanda.
enum DayMark { hasFree, full, unknown }

/// Tentukan penanda [date] dari daftar booking (yang sudah
/// dimuat). Slot dianggap bebas bila statusnya free DAN belum
/// lewat (untuk hari ini). Booking cancelled/rejected/expired
/// diabaikan oleh [slotStatuses] — semantik sama seperti grid.
DayMark dayMark(
  List<Booking> bookings,
  String fieldId,
  DateTime date,
  DateTime now,
) {
  final statuses = slotStatuses(bookings, fieldId, fmtDate(date));
  for (var h = openHour; h < closeHour; h++) {
    if (statuses[h] == SlotStatus.free && !isPastSlot(date, h, now)) {
      return DayMark.hasFree;
    }
  }
  return DayMark.full;
}

/// Nama hari & bulan Indonesia lengkap untuk tampilan tanggal.
const indoDaysFull = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];
const indoMonthsFull = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// "Jumat, 24 Oktober 2026"
String indoFullDate(DateTime d) =>
    '${indoDaysFull[d.weekday - 1]}, ${d.day} ${indoMonthsFull[d.month - 1]} ${d.year}';

/// "Oktober 2026" — judul bagian bulan di kalender.
String indoMonthYear(DateTime d) =>
    '${indoMonthsFull[d.month - 1]} ${d.year}';
