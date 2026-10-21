# Rencana Pengujian — Deofoot

*Mengikuti kerangka Test & Analysis Plan (Mauro Pezze & Michal Young, 2008) pada materi Pertemuan 3: Perencanaan & Proses Monitoring — Analisis & Pengujian Sistem (Nur Rahmat Dwi Riyanto, M.Kom).*

## 1. Tujuan

Memastikan Deofoot berperilaku sesuai spesifikasinya — khususnya pada aturan yang berdampak uang dan keadilan antrean: pencegahan double booking, alur status booking, langganan seri, dan kewenangan admin — serta memastikan setiap perubahan versi tidak merusak perilaku versi sebelumnya.

## 2. Aktivitas Kualitas yang Dilakukan

| Aktivitas | Teknik | Objek |
|---|---|---|
| Unit testing | White-box atas fungsi logika murni (Dart) | Ketersediaan slot, tumpang tindih, status, seri, laporan, rentang tanggal |
| Widget testing | Black-box pada komponen & layar | Grid jadwal, kalender, kartu seri, formulir, indikator |
| System testing | Skenario ujung-ke-ujung di aplikasi | Alur booking, langganan, verifikasi admin, laporan |
| Acceptance testing | Daftar kriteria penerimaan per rilis | Verdict QA independen + uji langsung di perangkat oleh pemilik project |
| Regression testing | Menjalankan ulang seluruh suite setiap versi | Seluruh test case versi sebelumnya (lihat dokumen 04) |
| Security review | Penelaahan Firestore Security Rules | Eskalasi hak admin, status awal booking, kewenangan ubah status |

## 3. Ketergantungan Antar Aktivitas

Unit dan widget test mendahului system testing (kegagalan unit menghentikan promosi build). Hasil system testing menjadi masukan acceptance testing. Regression testing berjalan pada setiap gerbang rilis: tidak ada rilis tanpa suite hijau penuh dan verdict QA independen.

## 4. Sumber Daya & Alokasi

- Perangkat uji: emulator Android API 34 dan satu perangkat fisik Android (POCO X3 Pro).
- Lingkungan data: project Firebase `deofoot` (Spark), region asia-southeast1; data uji terpisah dari data produksi melalui akun uji.
- Peran: pengembang (implementasi), QA independen (verifikasi & verdict), pemilik project (persetujuan rilis & uji perangkat).

## 5. Tonggak (Milestones) Terukur

| Versi | Cakupan | Hasil suite | Gerbang |
|---|---|---|---|
| v0.3 | Booking inti, admin dasar | 43/43 | QA lulus 10/10 |
| v0.4 | Langganan, laporan PDF, notifikasi, kelola lapangan, cari slot | 104/104 | QA lulus sesudah 1x rework |
| v0.4.1 | Micro-fix konfirmasi seri satu pintu | 113/113 | QA lulus, temuan nihil |
| v1.5.0 | Desain ulang total (presentasi) + rentang 90 hari | 170/170 | QA checkpoint + regresi penuh lulus; verifikasi pasca-rilis lulus |

Setiap rilis dinyatakan selesai hanya bila: (1) suite penuh hijau, (2) `flutter analyze` bersih, (3) verdict QA independen "LULUS", (4) artefak rilis terverifikasi hash-nya, dan (5) uji perangkat oleh pemilik project lulus.

## 6. Monitoring Proses

Kemajuan pengujian dipantau per versi melalui tiga indikator: (a) jumlah & hasil test (hijau/gagal) per berkas, (b) jumlah deviasi terhadap spesifikasi yang ditemukan QA dan status perbaikannya, dan (c) waktu rata-rata hingga kegagalan ditemukan (defect ditemukan pada tahap QA kode, bukan di perangkat pengguna — contoh pada Bagian 7). Bila indikator memburuk, tindakan korektif berupa pengetatan spesifikasi dan daftar periksa gerbang diterapkan sebelum rilis berikutnya.

## 7. Perbaikan Proses melalui Root Cause Analysis (RCA)

Tiga contoh nyata selama project berjalan:

1. **Deviasi besar pada implementasi awal v0.4** — *Fault*: 18+ deviasi dari spesifikasi pada build pertama. *Why*: implementasi dikerjakan dari ringkasan, bukan dari dokumen spesifikasi. *Pencegahan*: aturan kerja "selalu dari berkas spesifikasi", spesifikasi dibubuhi hash dan dilampirkan pada setiap paket tugas/QA.
2. **Kedip (flicker) pada layar Jadwal** — *Fault*: grid slot menggambar ulang dan sesaat menampilkan status salah saat ganti tanggal. *Why*: status tanggal baru dihitung dari snapshot data tanggal lama yang masih dimuat. *Pencegahan*: aturan "data lama tampil sampai data baru siap" + test widget pengunci stabilitas grid; akar penyebab dihilangkan, bukan gejalanya.
3. **Alarm palsu verifikasi artefak** — *Fault*: dua APK berbeda sempat terbaca "identik". *Why*: perbandingan memakai properti yang tidak tersedia pada runtime lama sehingga merosot menjadi perbandingan panjang berkas. *Pencegahan*: verifikasi artefak wajib memakai hash SHA-256 atas entri hasil ekstrak.

## 8. Risiko & Rencana Darurat

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Perubahan presentasi merusak fungsi | Tinggi | Batas keras: logika & model data dibekukan; ekuivalensi dibuktikan QA di tingkat berkas |
| Aturan keamanan (rules) bocor | Tinggi | Rules ditelaah terpisah; publish hanya sesudah review independen + persetujuan |
| Ketergantungan layanan cloud saat demo | Sedang | Rekaman demo disiapkan sebagai cadangan; akun & data demo disiapkan sebelumnya |
