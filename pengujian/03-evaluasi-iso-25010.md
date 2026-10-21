# Evaluasi Kualitas Perangkat Lunak — ISO/IEC 25010

*Mengikuti materi Pertemuan 6: ISO/IEC 25010 sebagai standar evaluasi kualitas perangkat lunak. Penilaian dilakukan terhadap Deofoot v1.5.0 berdasarkan bukti pengujian dan pemakaian nyata, dengan skala: Baik / Cukup / Kurang.*

## 1. Hasil Penilaian per Karakteristik

| Karakteristik | Sub-kriteria (contoh) | Nilai | Bukti & Penjelasan |
|---|---|---|---|
| **Functional Suitability** (Kesesuaian Fungsional) | Ketepatan (Accuracy); Kesesuaian fungsi | **Baik** | Seluruh fungsi spesifikasi terimplementasi: booking anti-double-booking, langganan seri satu konfirmasi, laporan, kelola lapangan, cari slot. 170/170 test lulus; deteksi tumpang tindih tepat termasuk tepi bersentuhan. |
| **Performance Efficiency** (Efisiensi Performa) | Waktu tanggapan; Penggunaan sumber daya | **Baik** | Animasi dibatasi pada transform & opacity (target 60fps); status jadwal tidak dihitung ulang dari data basi; ukuran APK ±24 MB wajar untuk aplikasi Flutter dengan font terbundel. |
| **Compatibility** (Kompatibilitas) | Koeksistensi; Interoperabilitas | **Cukup** | Berjalan di Android (diuji pada emulator API 34 & perangkat fisik POCO). Belum ada versi iOS; interoperabilitas dengan Firebase berjalan baik melalui SDK resmi. |
| **Usability** (Kemudahan Penggunaan) | Kepahaman (Understandability); Kepuasan pengguna | **Baik** | Bahasa status selalu warna + label teks; kalender memberikan penanda ketersediaan per tanggal; alur booking berindikator langkah. Pada uji perangkat, pemilik project menilai tampilan akhir lebih baik dari versi sebelumnya. |
| **Reliability** (Keandalan) | Ketahanan kegagalan; Ketersediaan | **Baik** | Pending kedaluwarsa otomatis mencegah slot tertahan selamanya; perubahan status seri atomik (satu transaksi) mencegah keadaan setengah jadi; data lama tetap tampil saat data baru dimuat sehingga layar tidak pernah kosong/berkedip. |
| **Security** (Keamanan) | Keamanan data; Ketahanan terhadap serangan | **Baik** | Autentikasi Firebase; otorisasi ditegakkan server-side oleh Security Rules: pengguna tidak dapat mengangkat dirinya menjadi admin, booking selalu lahir pending, hanya admin yang dapat mengubah status verifikasi. Rules ditelaah independen sebelum diterbitkan. Catatan jujur: daftar booking dapat dibaca pengguna yang login (keputusan sadar untuk MVP demi deteksi bentrok) — risiko diterima dan terdokumentasi. |
| **Maintainability** (Kemudahan Perawatan) | Modularitas; Kemudahan diuji (Testability) | **Baik** | Logika bisnis terpisah sebagai fungsi murni (32 berkas `lib/`, logika per domain) sehingga dapat diuji unit tanpa emulator; perubahan desain ulang total (Fase G) terbukti tidak menyentuh satu pun berkas logika (ekuivalensi byte-identik dibuktikan QA). |
| **Portability** (Portabilitas) | Kemudahan pemasangan; Adaptabilitas | **Cukup** | Pemasangan via APK langsung berjalan mulus di dua lingkungan uji; distribusi belum melalui Play Store dan platform masih tunggal (Android). |

## 2. Kesimpulan

Karakteristik yang paling menentukan untuk sistem pemesanan — kesesuaian fungsional, keandalan, dan keamanan — seluruhnya bernilai **Baik** dengan bukti pengujian yang dapat ditelusuri (suite 170 test, verdict QA independen, pengujian rules di emulator). Dua nilai **Cukup** (kompatibilitas & portabilitas) bersifat keterbatasan cakupan platform yang disadari sejak awal (MVP Android), bukan cacat perilaku. Tidak ada karakteristik bernilai Kurang.

## 3. Rekomendasi Perbaikan (di luar cakupan rilis ini)

1. Membatasi keterbacaan daftar booking per pengguna untuk menaikkan aspek keamanan data.
2. Menambah target iOS untuk menaikkan kompatibilitas & portabilitas.
3. Menambah pemantauan performa terukur (waktu muat layar Jadwal) agar efisiensi performa dinilai dari angka, bukan hanya rancangan.
