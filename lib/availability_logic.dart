import 'booking_logic.dart';
import 'models.dart';

/// Cari lapangan yang bebas untuk SATU rentang pilihan user
/// (SPEK-V04 Fase D, rework T8): user memilih satu tanggal, satu jam
/// mulai, dan durasi 1–4 jam berurutan; hasil = daftar LAPANGAN aktif
/// yang SELURUH slot pada rentang [jamMulai, jamMulai+durasi) bebas.
///
/// Definisi "terisi" sama persis dengan layar Jadwal: memakai
/// [hasConflict] yang sama — booking pending/confirmed menempati
/// slotnya; cancelled/rejected/expired dianggap bebas; tepi
/// bersentuhan bukan konflik. Grid global 08.00–22.00 (rework T5):
/// rentang yang keluar grid tidak menghasilkan lapangan apa pun.
List<Field> lapanganBebas({
  required List<Field> fields,
  required List<Booking> bookings,
  required String tanggal, // yyyy-MM-dd
  required int jamMulai,
  required int durasiJam,
}) {
  if (durasiJam < 1 || durasiJam > 4) return const [];
  if (jamMulai < openHour || jamMulai + durasiJam > closeHour) {
    return const [];
  }
  final hasil = fields
      .where((f) => f.isActive)
      .where((f) => !hasConflict(
            bookings,
            f.id,
            tanggal,
            jamMulai * 60,
            (jamMulai + durasiJam) * 60,
          ))
      .toList();
  hasil.sort((a, b) => a.name.compareTo(b.name));
  return hasil;
}

/// Apakah rentang [startHour, startHour+hours) boleh dipra-seleksi
/// di grid Jadwal (Fase G §3.4: hasil Cari Slot membuka Jadwal
/// dengan slot terkait sudah terpilih)? Syaratnya persis aturan
/// selectable grid: semua jam bebas, belum lewat, dan rentang di
/// dalam grid global. Murni — bisa di-test.
bool canPreselect(
  Map<int, SlotStatus> statuses,
  int startHour,
  int hours,
  bool Function(int hour) isPast,
) {
  if (hours < 1 || startHour < openHour || startHour + hours > closeHour) {
    return false;
  }
  for (var h = startHour; h < startHour + hours; h++) {
    if ((statuses[h] ?? SlotStatus.free) != SlotStatus.free) return false;
    if (isPast(h)) return false;
  }
  return true;
}
