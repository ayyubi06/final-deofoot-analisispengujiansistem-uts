// Logika murni kelola lapangan admin (Fase C v0.4): slug id, id unik,
// dan validasi form lapangan.

/// Slug id dokumen dari nama lapangan: huruf kecil; setiap run karakter
/// non-alfanumerik menjadi satu '-'; tepi dirapikan.
/// Nama kosong/tanpa alfanumerik → 'lapangan'.
String slugFieldId(String name) {
  final s = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'lapangan' : s;
}

/// Id unik untuk lapangan baru: slug nama; bila sudah dipakai, tambah
/// akhiran -2, -3, … sampai bebas.
String fieldIdUnik(String name, Set<String> existingIds) {
  final base = slugFieldId(name);
  if (!existingIds.contains(base)) return base;
  var i = 2;
  while (existingIds.contains('$base-$i')) {
    i++;
  }
  return '$base-$i';
}

/// Parse teks harga: buang semua non-digit lalu baca angka.
/// "150.000" → 150000; teks tanpa digit → 0.
int parseHarga(String teks) =>
    int.tryParse(teks.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Validasi form lapangan. Mengembalikan pesan kesalahan, atau null
/// bila valid. Aturan (SPEK-V04 Fase C): nama tidak kosong, harga > 0.
String? validasiField({
  required String nama,
  required String hargaTeks,
}) {
  if (nama.trim().isEmpty) return 'Nama lapangan wajib diisi.';
  if (parseHarga(hargaTeks) <= 0) {
    return 'Harga per jam harus angka lebih dari 0.';
  }
  return null;
}

/// Inisial nama lapangan untuk placeholder foto (SPEK-V04 C2: warna
/// identitas + inisial): huruf pertama kata pertama + huruf pertama
/// kata kedua (bila ada), kapital. "Futsal L1" → "FL"; "Padel" → "P".
String inisialNama(String nama) {
  final kata = nama
      .trim()
      .split(RegExp(r'\s+'))
      .where((k) => k.isNotEmpty)
      .toList();
  if (kata.isEmpty) return '?';
  final pertama = kata[0][0].toUpperCase();
  if (kata.length == 1) return pertama;
  return '$pertama${kata[1][0].toUpperCase()}';
}
