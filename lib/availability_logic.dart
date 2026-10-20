import 'dart:math';
import 'booking_logic.dart';
import 'models.dart';

/// Satu slot kosong hasil pencarian lintas lapangan (Fase D v0.4).
class SlotKosong {
  final Field field;
  final int startHour;
  final int endHour; // eksklusif
  const SlotKosong({
    required this.field,
    required this.startHour,
    required this.endHour,
  });
}

/// Cari slot kosong di semua lapangan AKTIF untuk satu tanggal.
///
/// Definisi "terisi" sama persis dengan layar Jadwal: memakai
/// [hasConflict] yang sama — booking pending/confirmed menempati
/// slotnya; cancelled/rejected/expired dianggap bebas; tepi
/// bersentuhan bukan konflik.
///
/// Aturan lain (SPEK-V04 Fase D):
/// - jendela hasil = irisan [jamMulai, jamSelesai] dengan jam
///   operasional lapangan (scheduleGrid);
/// - untuk hari ini, slot yang sudah lewat tidak ditawarkan;
/// - hasil terurut jam mulai, lalu nama lapangan.
List<SlotKosong> cariSlotKosong({
  required List<Field> fields,
  required Map<String, List<Booking>> bookingsPerField,
  required String tanggal, // yyyy-MM-dd
  required int durasiJam,
  required int jamMulai,
  required int jamSelesai,
  required DateTime now,
}) {
  final hasil = <SlotKosong>[];
  if (durasiJam <= 0) return hasil;
  final dp = tanggal.split('-').map(int.parse).toList();
  final tgl = DateTime(dp[0], dp[1], dp[2]);
  final hariIni = tanggal == fmtDate(now);
  for (final f in fields) {
    if (!f.isActive) continue;
    final lo = max(jamMulai, f.openHour);
    final hi = min(jamSelesai, f.closeHour);
    final bookings = bookingsPerField[f.id] ?? const <Booking>[];
    for (var s = lo; s + durasiJam <= hi; s++) {
      if (hariIni && isPastSlot(tgl, s, now)) continue;
      if (hasConflict(bookings, f.id, tanggal, s * 60, (s + durasiJam) * 60)) {
        continue;
      }
      hasil.add(SlotKosong(field: f, startHour: s, endHour: s + durasiJam));
    }
  }
  hasil.sort((a, b) {
    final c = a.startHour.compareTo(b.startHour);
    return c != 0 ? c : a.field.name.compareTo(b.field.name);
  });
  return hasil;
}
