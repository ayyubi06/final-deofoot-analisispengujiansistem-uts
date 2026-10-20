import 'booking_logic.dart';
import 'models.dart';

/// Logika murni laporan admin (Fase B v0.4).
///
/// ATURAN TEGAS spek: angka laporan (jumlah booking, slot terisi,
/// pendapatan) HANYA dari booking berstatus `confirmed` (Disetujui) pada
/// rentang tanggal MAIN-nya. Booking pending/cancelled/rejected/expired
/// tidak pernah terhitung sebagai pendapatan.

/// Nama hari Indonesia (bentuk panjang). DateTime.weekday: 1=Senin..7=Minggu.
String namaHari(DateTime d) {
  const h = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  return h[d.weekday - 1];
}

/// Nama bulan Indonesia (bentuk panjang), bulan 1–12.
String namaBulan(int bulan) {
  const b = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  return b[bulan - 1];
}

/// "Rabu, 21 Oktober 2026".
String tanggalIndonesia(DateTime d) =>
    '${namaHari(d)}, ${d.day} ${namaBulan(d.month)} ${d.year}';

/// Jenis rentang laporan.
enum JenisRentang { hariIni, mingguIni, bulanIni, pilihan }

/// Rentang tanggal inklusif (mulai, akhir) untuk preset.
/// Minggu ini = Senin s/d Minggu pekan berjalan.
/// Untuk [JenisRentang.pilihan], tanggal datang dari pemilih di UI;
/// fungsi ini mengembalikan (hari ini, hari ini) sebagai bawaan.
(DateTime, DateTime) rentangPreset(JenisRentang jenis, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (jenis) {
    case JenisRentang.hariIni:
      return (today, today);
    case JenisRentang.mingguIni:
      final senin = today.subtract(Duration(days: today.weekday - 1));
      return (senin, senin.add(const Duration(days: 6)));
    case JenisRentang.bulanIni:
      return (
        DateTime(today.year, today.month, 1),
        DateTime(today.year, today.month + 1, 0),
      );
    case JenisRentang.pilihan:
      return (today, today);
  }
}

/// Agregat per lapangan dalam laporan.
class AggLapangan {
  final String fieldId;
  final String fieldName;
  int jumlahBooking = 0;
  int pendapatan = 0;
  AggLapangan(this.fieldId, this.fieldName);
}

/// Hasil agregasi laporan satu periode.
class LaporanPeriode {
  final DateTime mulai;
  final DateTime akhir;
  final int jumlahBooking;
  final int slotTerisi;
  final int pendapatan;
  final List<AggLapangan> perLapangan; // urut pendapatan terbesar dulu
  final Map<String, int> pendapatanPerTanggal; // yyyy-MM-dd → rupiah
  final Map<String, int> bookingPerTanggal; // yyyy-MM-dd → jumlah
  const LaporanPeriode({
    required this.mulai,
    required this.akhir,
    required this.jumlahBooking,
    required this.slotTerisi,
    required this.pendapatan,
    required this.perLapangan,
    required this.pendapatanPerTanggal,
    required this.bookingPerTanggal,
  });
}

/// Agregasi laporan dari daftar booking (semua status boleh masuk daftar;
/// fungsi ini yang menyaring). Rentang inklusif berdasarkan tanggal main.
LaporanPeriode hitungLaporan(
    List<Booking> bookings, DateTime mulai, DateTime akhir) {
  final mStr = fmtDate(mulai);
  final aStr = fmtDate(akhir);
  var jumlah = 0;
  var slot = 0;
  var uang = 0;
  final perField = <String, AggLapangan>{};
  final perTglUang = <String, int>{};
  final perTglBooking = <String, int>{};
  for (final b in bookings) {
    if (b.status != 'confirmed') continue; // HANYA Disetujui
    if (b.date.compareTo(mStr) < 0 || b.date.compareTo(aStr) > 0) continue;
    jumlah++;
    slot += (b.endMinutes - b.startMinutes) ~/ 60;
    uang += b.totalPrice;
    final agg = perField.putIfAbsent(
        b.fieldId, () => AggLapangan(b.fieldId, b.fieldName));
    agg.jumlahBooking++;
    agg.pendapatan += b.totalPrice;
    perTglUang[b.date] = (perTglUang[b.date] ?? 0) + b.totalPrice;
    perTglBooking[b.date] = (perTglBooking[b.date] ?? 0) + 1;
  }
  final list = perField.values.toList()
    ..sort((a, b) => b.pendapatan.compareTo(a.pendapatan));
  return LaporanPeriode(
    mulai: mulai,
    akhir: akhir,
    jumlahBooking: jumlah,
    slotTerisi: slot,
    pendapatan: uang,
    perLapangan: list,
    pendapatanPerTanggal: perTglUang,
    bookingPerTanggal: perTglBooking,
  );
}
