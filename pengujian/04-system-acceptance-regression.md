# System, Acceptance & Regression Testing — Deofoot

*Mengikuti materi Pertemuan 7 (Mauro Pezze dkk., 2008): system testing bersifat menyeluruh, berbasis spesifikasi perilaku yang dapat diamati, dan independen; acceptance testing memandu keputusan kelayakan rilis; regression testing menjalankan kembali test case versi sebelumnya — dengan perhatian bahwa test case lama dapat menjadi obsolete atau redundant.*

## 1. System Testing

Pengujian dilakukan pada sistem utuh (aplikasi + Firebase) melalui skenario ujung-ke-ujung. Hasil aktual dicatat apa adanya pada perangkat uji.

| ID | Skenario | Langkah Ringkas | Hasil yang Diharapkan | Hasil Aktual |
|---|---|---|---|---|
| ST-01 | Booking normal | Login → pilih lapangan → pilih tanggal & slot bebas → buat booking → unggah bukti | Booking *pending*; muncul di Booking Saya | Sesuai |
| ST-02 | Penolakan double booking | Dua akun meminta slot yang sama; akun pertama terkonfirmasi | Akun kedua tertolak; slot terbaca terisi | Sesuai |
| ST-03 | Langganan seri | Buat seri 4 pertemuan → bayar total → admin buka rincian seri → Terima | 4 pertemuan terkonfirmasi sekaligus; total = 4 × tarif | Sesuai (seri produksi nyata berhasil dibuat & tampil benar) |
| ST-04 | Verifikasi individual | Admin menerima satu booking individual dari daftar verifikasi | Hanya booking itu yang berubah; seri tidak tercampur di daftar | Sesuai (sesudah micro-fix v0.4.1) |
| ST-05 | Laporan admin | Buka laporan rentang 7 hari → ekspor PDF | PDF berkop "Laporan Deofoot"; pendapatan hanya dari booking disetujui; okupansi terhitung benar (1 dari 98 slot = 1,0%) | Sesuai |
| ST-06 | Cari slot lintas lapangan | Cari slot kosong jam tertentu di semua lapangan → pilih hasil | Jadwal terbuka dengan slot hasil terpraseleksi bila masih bebas | Sesuai |
| ST-07 | Pembatalan dalam batas | Batalkan booking 3 jam sebelum mulai | Status menjadi Dibatalkan; slot bebas kembali | Sesuai |
| ST-08 | Kedaluwarsa pending | Biarkan pending melewati 30 menit | Status kedaluwarsa; slot dapat dipesan ulang | Sesuai |

## 2. Acceptance Testing

Keputusan rilis pada project ini diformalkan sebagai gerbang berlapis — acceptance testing bukan satu peristiwa, melainkan rangkaian kriteria yang seluruhnya harus terpenuhi:

1. **Suite otomatis hijau penuh** dan analisis statis bersih pada commit yang dirilis.
2. **Verdict QA independen "LULUS"** atas paket sumber yang sama (hash terverifikasi) — termasuk ekuivalensi fungsi terhadap versi sebelumnya.
3. **Verifikasi artefak**: APK hasil build terverifikasi (ukuran + hash SHA-256 berkas dan entri kunci di dalamnya; nomor versi terbaca dari manifes).
4. **Verifikasi pasca-rilis independen** oleh QA.
5. **Uji penerimaan pengguna di perangkat fisik** oleh pemilik project: alur utama dijalankan, tampilan dinilai, dan — untuk v1.5.0 — perilaku pindah tanggal di Jadwal diamati terhadap rekaman pembanding versi sebelumnya (kriteria anti-kedip ketiga).

Riwayat keputusan: v0.4 sempat **ditolak** pada gerbang ini (18+ deviasi ditemukan QA) dan hanya dirilis sesudah perbaikan terbukti; v0.4.1 dan v1.5.0 lulus seluruh gerbang tanpa deviasi fungsi.

## 3. Regression Testing

### 3.1 Metode

Setiap versi menjalankan kembali **seluruh** test case versi sebelumnya ditambah test baru untuk perilaku baru. Suite tidak pernah dikurangi untuk membuat hasil tampak hijau; test yang gagal karena perilaku berubah secara sah diklasifikasikan dulu (Bagian 3.3) sebelum diubah.

### 3.2 Pertumbuhan Suite

| Versi | Jumlah Test | Keterangan |
|---|---|---|
| v0.3 | 43 | Suite awal booking inti |
| v0.4 | 104 | +61: seri, laporan, notifikasi, kelola lapangan, cari slot |
| v0.4.1 | 113 | +9: penyaringan seri dari daftar individual & rincian seri |
| Checkpoint Fase G (Tahap 3) | 150 | +37: token, komponen, navigasi, kalender, anti-kedip |
| v1.5.0 | 170 | +20: booking/pembayaran, langganan, admin, auth/profil; termasuk test G6 (rentang 90 hari) |

Seluruh 113 test warisan v0.4.1 terverifikasi **utuh per berkas** pada v1.5.0 (dibuktikan QA saat regresi penuh) — bukti regression testing berjalan sebagaimana mestinya pada perubahan sebesar desain ulang total.

### 3.3 Klasifikasi Test Case: Obsolete & Redundant

Sesuai peringatan materi Pertemuan 7, menjalankan kembali test lama secara membabi buta bermasalah karena sebagian test mengunci perilaku lama. Klasifikasi yang diterapkan:

| Test / Kelompok | Klasifikasi | Alasan & Tindakan |
|---|---|---|
| Test yang mengharapkan pertemuan seri tampil sebagai kartu individual di daftar verifikasi | **Obsolete** | Perilaku diubah secara sah oleh keputusan desain (konfirmasi seri satu pintu, v0.4.1). Test diganti test penyaring seri + test rincian seri. |
| Test token warna tema lama (navy/oranye) | **Obsolete** | Tema diganti total oleh desain "Pitch" pada Fase G. Diganti 11 test token baru yang mengunci nilai token Pitch. |
| Test urutan stagger pembuka aplikasi (900 ms) | **Obsolete** | Desain gerak baru menetapkan satu crossfade masuk 250 ms. Test disesuaikan dengan spesifikasi gerak baru. |
| Test rentang pemesanan 60 hari | **Diperbarui (bukan dibuang)** | Keputusan pemilik project mengubah cakrawala menjadi 90 hari (G6); test rentang diperbarui ke H+89 dan tetap menjadi penjaga batas (H+90 tetap ditolak). |
| Pemeriksaan tumpang tindih di dua lapisan (logika booking & logika ketersediaan) | **Redundant — dipertahankan dengan sengaja** | Keduanya tampak menguji hal sama, tetapi menjaga dua jalur kode berbeda yang sama-sama menentukan bentrok; menghapus salah satu menurunkan perlindungan pada aturan paling kritis. Dinyatakan eksplisit agar tidak dihapus sebagai "duplikat". |

Di luar tabel ini, tidak ditemukan test redundant lain pada suite akhir: pengorganisasian suite per berkas logika membuat kepemilikan tiap test jelas.
