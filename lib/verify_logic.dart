import 'models.dart';

/// Logika murni layar Verifikasi (micro-fix v0.4.1 — Addendum 4
/// SPEK-V04: konfirmasi seri SATU kartu, rincian di dalam).

/// Booking yang tampil sebagai item individual di daftar verifikasi
/// biasa. Pertemuan seri DIKELUARKAN: seri dikonfirmasi satu kali
/// lewat kartu seri di bagian "Langganan menunggu", bukan per
/// pertemuan (Addendum 4).
List<Booking> bookingVerifikasiIndividual(List<Booking> semua) =>
    semua.where((b) => b.seriesId == null).toList();

/// Pertemuan satu seri terurut tanggal (lalu jam mulai) untuk
/// daftar di rincian seri.
List<Booking> pertemuanSeriUrut(List<Booking> meetings) {
  final list = [...meetings];
  list.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.startMinutes.compareTo(b.startMinutes);
  });
  return list;
}

/// Jumlah pertemuan yang IKUT berubah saat admin menerima/menolak
/// seri — persis sasaran setSeriesStatus: hanya yang masih
/// 'pending'. Pertemuan berstatus lain (terutama 'cancelled')
/// tidak ikut berubah (semantik E6/Addendum 4).
int jumlahPertemuanIkutBerubah(List<Booking> meetings) =>
    meetings.where((b) => b.status == 'pending').length;

/// Pertemuan yang TIDAK ikut berubah oleh keputusan seri
/// (status bukan 'pending').
List<Booking> pertemuanTidakBerubah(List<Booking> meetings) =>
    meetings.where((b) => b.status != 'pending').toList();
