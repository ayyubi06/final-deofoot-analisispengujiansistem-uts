import 'models.dart';

/// Logika murni notifikasi lokal (Fase A v0.4).
///
/// Dua pengingat per booking milik user:
/// - bayar: booking `pending` → dibuat saat booking, tampil pada
///   createdAt + 15 menit (jendela bayar 30 menit; pengingat di tengah).
/// - main: booking `confirmed` → tampil 2 jam sebelum waktu mulai.
///
/// Semua keputusan dihitung di sini dari daftar booking + waktu sekarang,
/// supaya bisa di-unit-test tanpa plugin/platform.

/// Jenis pengingat.
enum JenisPengingat { bayar, main }

/// Satu rencana notifikasi hasil perhitungan.
class RencanaNotifikasi {
  final int id;
  final String bookingId;
  final JenisPengingat jenis;

  /// Waktu tampil yang direncanakan. Bila [segera] true, nilai ini sudah
  /// lewat dan notifikasi harus ditampilkan langsung (sekali).
  final DateTime waktu;
  final bool segera;
  final String judul;
  final String isi;

  const RencanaNotifikasi({
    required this.id,
    required this.bookingId,
    required this.jenis,
    required this.waktu,
    required this.segera,
    required this.judul,
    required this.isi,
  });
}

/// Hash string yang STABIL antar-run (beda dari String.hashCode yang tidak
/// dijamin stabil) — djb2 di atas code unit, dimask ke 29 bit.
int _hashStabil(String s) {
  var h = 5381;
  for (final c in s.codeUnits) {
    h = ((h * 33) ^ c) & 0x1FFFFFFF;
  }
  return h;
}

/// Id notifikasi deterministik dari bookingId + jenis (stabil antar-run,
/// unik per booking per jenis, positif, muat int32).
int idNotifikasi(String bookingId, JenisPengingat jenis) =>
    _hashStabil(bookingId) * 2 + (jenis == JenisPengingat.main ? 1 : 0);

String _isi(Booking b) => '${b.fieldName} • ${b.date} • ${b.startTime}–${b.endTime}';

/// Bangun rencana notifikasi dari booking-booking milik user.
///
/// Aturan (SPEK-V04 Fase A):
/// - status selain pending/confirmed → tidak ada pengingat.
/// - waktu main sudah lewat → tidak ada pengingat.
/// - pending: pengingat bayar pada createdAt+15 mnt, HANYA bila batas itu
///   masih di depan. Lewat batas → tidak ada pengingat susulan.
/// - confirmed: pengingat main pada mulai−2 jam; bila titik itu sudah
///   lewat tetapi waktu main masih di depan → tampil segera (sekali).
List<RencanaNotifikasi> rencanaNotifikasi({
  required List<Booking> bookings,
  required DateTime now,
}) {
  final hasil = <RencanaNotifikasi>[];
  for (final b in bookings) {
    if (b.status != 'pending' && b.status != 'confirmed') continue;
    final mulai = b.startDateTime;
    if (!mulai.isAfter(now)) continue; // waktu main sudah lewat
    if (b.status == 'pending') {
      final batas = b.createdAt.add(const Duration(minutes: 15));
      if (!batas.isAfter(now)) continue; // tidak ada pengingat susulan
      hasil.add(RencanaNotifikasi(
        id: idNotifikasi(b.id, JenisPengingat.bayar),
        bookingId: b.id,
        jenis: JenisPengingat.bayar,
        waktu: batas,
        segera: false,
        judul: 'Selesaikan pembayaran booking',
        isi: _isi(b),
      ));
    } else {
      final titik = mulai.subtract(const Duration(hours: 2));
      final segera = !titik.isAfter(now);
      hasil.add(RencanaNotifikasi(
        id: idNotifikasi(b.id, JenisPengingat.main),
        bookingId: b.id,
        jenis: JenisPengingat.main,
        waktu: titik,
        segera: segera,
        judul: 'Pengingat main',
        isi: _isi(b),
      ));
    }
  }
  hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
  return hasil;
}

/// Hasil rekonsiliasi rencana vs keadaan plugin.
class HasilRekonsiliasi {
  /// Rencana masa depan yang belum terjadwal → jadwalkan.
  final List<RencanaNotifikasi> jadwalkan;

  /// Rencana "tampil segera" yang belum pernah ditampilkan → tampilkan.
  final List<RencanaNotifikasi> tampilkanSegera;

  /// Id terjadwal yang tidak lagi ada di rencana → batalkan.
  final List<int> batalkan;

  const HasilRekonsiliasi({
    required this.jadwalkan,
    required this.tampilkanSegera,
    required this.batalkan,
  });
}

/// Rekonsiliasi idempoten (SPEK-V04 Fase A): bandingkan rencana dengan
/// notifikasi yang sedang terjadwal di plugin dan yang sudah pernah
/// ditampilkan sebagai "segera".
/// - rencana masa depan belum terjadwal → jadwalkan.
/// - rencana masa depan sudah terjadwal → biarkan (tidak digandakan).
/// - terjadwal tetapi tidak ada di rencana (booking berubah status /
///   dibatalkan / sudah lewat) → batalkan.
/// - rencana segera yang sudah pernah ditampilkan → tidak diulang.
HasilRekonsiliasi rekonsiliasiNotifikasi({
  required List<RencanaNotifikasi> rencana,
  required Set<int> idTerjadwal,
  required Set<int> idSudahTampil,
}) {
  final jadwalkan = <RencanaNotifikasi>[];
  final tampilkan = <RencanaNotifikasi>[];
  for (final r in rencana) {
    if (r.segera) {
      if (!idSudahTampil.contains(r.id) && !idTerjadwal.contains(r.id)) {
        tampilkan.add(r);
      }
    } else if (!idTerjadwal.contains(r.id)) {
      jadwalkan.add(r);
    }
  }
  final idRencana = rencana.map((r) => r.id).toSet();
  final batalkan =
      idTerjadwal.where((id) => !idRencana.contains(id)).toList()..sort();
  return HasilRekonsiliasi(
    jadwalkan: jadwalkan,
    tampilkanSegera: tampilkan,
    batalkan: batalkan,
  );
}
