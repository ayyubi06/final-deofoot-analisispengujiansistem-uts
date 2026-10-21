import 'booking_logic.dart';
import 'models.dart';

// Logika murni langganan slot rutin / seri (Fase E v0.4).
//
// Prinsip spek: seri bersifat ALL-OR-NOTHING — bila satu saja tanggal
// bentrok, seri tidak dibuat sama sekali dan tidak ada booking yatim.

/// Ekspansi seri mingguan: [jumlahPertemuan] tanggal (yyyy-MM-dd) pada
/// hari yang sama, mulai dari [tanggalMulai] (pertemuan pertama).
List<String> ekspansiTanggalSeri(DateTime tanggalMulai, int jumlahPertemuan) {
  final base = DateTime(tanggalMulai.year, tanggalMulai.month, tanggalMulai.day);
  return [
    for (var i = 0; i < jumlahPertemuan; i++)
      fmtDate(base.add(Duration(days: 7 * i)))
  ];
}

/// Total harga satu seri penuh: pertemuan × durasi × tarif (snapshot).
int totalHargaSeri({
  required int jumlahPertemuan,
  required int durasiJam,
  required int pricePerHour,
}) =>
    jumlahPertemuan * bookingTotal(durasiJam, pricePerHour);

/// Daftar tanggal seri yang bentrok dengan booking aktif yang sudah ada
/// (memakai [hasConflict] yang sama dengan booking biasa & Jadwal).
/// Hasil kosong = seri aman dibuat.
List<String> tanggalKonflikSeri({
  required List<String> tanggalSeri,
  required Map<String, List<Booking>> bookingsPerTanggal,
  required String fieldId,
  required int startMin,
  required int endMin,
}) {
  final konflik = <String>[];
  for (final t in tanggalSeri) {
    final bs = bookingsPerTanggal[t] ?? const <Booking>[];
    if (hasConflict(bs, fieldId, t, startMin, endMin)) konflik.add(t);
  }
  return konflik;
}

/// Status efektif seri untuk tampilan:
/// - dokumen `confirmed` dan pertemuan terakhir sudah berakhir → 'selesai'
/// - selain itu status dokumen apa adanya.
String statusSeriEfektif(SubscriptionSeries s, DateTime now) {
  if (s.status != 'confirmed') return s.status;
  final terakhir = s.meetingDates.isNotEmpty ? s.meetingDates.last : s.endDate;
  if (terakhir.isEmpty || s.endTime.isEmpty) return s.status;
  final dp = terakhir.split('-').map(int.parse).toList();
  final tp = s.endTime.split(':').map(int.parse).toList();
  final akhirTerakhir = DateTime(dp[0], dp[1], dp[2], tp[0], tp[1]);
  return akhirTerakhir.isAfter(now) ? s.status : 'selesai';
}

/// Label Indonesia status seri (dokumen maupun efektif).
String labelStatusSeri(String status) {
  switch (status) {
    case 'pending':
      return 'Menunggu verifikasi';
    case 'confirmed':
      return 'Aktif';
    case 'selesai':
      return 'Selesai';
    case 'rejected':
      return 'Ditolak';
    case 'cancelled':
      return 'Dibatalkan';
    default:
      return status;
  }
}

/// Pertemuan seri yang termasuk "sisa seri" untuk pembatalan massal
/// (SPEK-V04 E7): hanya pertemuan mendatang yang masih **Disetujui
/// (confirmed)** — yang pending TIDAK ikut dibatalkan (rework T12).
List<Booking> sisaPertemuan(List<Booking> bookingsSeri, DateTime now) {
  return bookingsSeri
      .where((b) => b.status == 'confirmed' && b.startDateTime.isAfter(now))
      .toList();
}

/// Tanggal pertemuan pertama seri (SPEK-V04 E2): kemunculan pertama
/// [weekday] (1=Senin .. 7=Minggu) MULAI BESOK dari [hariIni].
/// Bila besok tepat hari terpilih → besok; bila hari ini yang terpilih
/// → pekan depan (+7 dari hari ini lewat pencarian maju).
DateTime tanggalPertamaUntukHari(int weekday, DateTime hariIni) {
  var d = DateTime(hariIni.year, hariIni.month, hariIni.day)
      .add(const Duration(days: 1));
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}
