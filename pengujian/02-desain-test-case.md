# Desain Test Case — Deofoot

*Mengikuti materi Pertemuan 4: Test Case Design — black-box testing dengan Equivalence Partitioning (EP) dan Boundary Value Analysis (BVA), format tabel Slide 14 (Test Case | Input | Expected Output). Setiap test case di bawah terpetakan ke test otomatis pada suite `flutter test` (total akhir 170 test).*

## 1. Teknik yang Dipakai

- **Equivalence Partitioning**: input dibagi ke kelas-kelas yang diperlakukan sama oleh program; satu wakil per kelas diuji. Contoh kelas pada domain slot: *bebas*, *pending*, *terisi*, *lewat*.
- **Boundary Value Analysis**: nilai di tepi rentang diuji secara khusus — tepi jam operasional (08.00 & 22.00), tepi tumpang tindih (slot bersentuhan tidak bentrok), tepi kedaluwarsa pending (30 menit), tepi pembatalan (2 jam), dan tepi rentang pemesanan (hari ini & H+89).
- **White-box (logic coverage)** pada fungsi murni: setiap cabang keputusan pada deteksi tumpang tindih dan semantik seri dilewati minimal satu test.

## 2. Tabel Test Case (pilihan inti)

| Test Case | Input | Expected Output |
|---|---|---|
| TC-01 Booking slot bebas | Lapangan Futsal 1, besok, 10.00–11.00, belum ada booking | Booking tersimpan berstatus *pending* |
| TC-02 Double booking persis sama | Slot sama persis dengan booking *confirmed* yang ada | Ditolak — slot terbaca terisi |
| TC-03 Tumpang tindih sebagian | Booking ada 10.00–12.00; minta 11.00–13.00 | Ditolak — tumpang tindih (11.00 < 12.00) |
| TC-04 Tepi bersentuhan (BVA) | Booking ada 10.00–11.00; minta 11.00–12.00 | Diterima — tepi bersentuhan bukan bentrok |
| TC-05 Slot tertahan pending | Booking *pending* aktif pada slot yang sama | Slot terbaca *Menunggu*, tidak dapat dipilih |
| TC-06 Pending kedaluwarsa (BVA) | Pending dibuat 31 menit lalu tanpa verifikasi | Status terbaca kedaluwarsa; slot kembali bebas |
| TC-07 Tepi kedaluwarsa (BVA) | Pending dibuat 29 menit lalu | Masih *pending*; slot masih tertahan |
| TC-08 Pembatalan tepat batas (BVA) | Booking mulai 3 jam lagi; dibatalkan sekarang (≥ 2 jam) | Pembatalan diterima |
| TC-09 Pembatalan lewat batas (BVA) | Booking mulai 1 jam lagi; dibatalkan sekarang | Ditolak — melewati batas 2 jam |
| TC-10 Slot di luar jam operasional (EP tidak valid) | Minta slot 22.00–23.00 | Ditolak — di luar grid 08.00–22.00 |
| TC-11 Slot yang sudah lewat | Hari ini, jam yang sudah berlalu | Terbaca *Lewat*, tidak dapat dipilih |
| TC-12 Total harga multi-slot | 3 slot Futsal @ Rp120.000 | Total Rp360.000 |
| TC-13 Seri langganan valid | Setiap Selasa 19.00, 4 pertemuan, mulai Selasa depan | Seri berisi 4 booking terkait satu `seriesId`; total = 4 × harga |
| TC-14 Seri bentrok satu tanggal (all-or-nothing) | Satu dari 4 tanggal seri ternyata terisi | Seluruh seri ditolak — tidak ada pertemuan yang tercipta |
| TC-15 Konfirmasi seri oleh admin | Admin menekan Terima pada rincian seri | Seluruh pertemuan berubah status dalam satu transaksi |
| TC-16 Seri tidak tampil individual | Daftar verifikasi admin memuat seri pending | Pertemuan seri tidak muncul sebagai kartu individual; yang tampil kartu ringkasan seri |
| TC-17 Tepi rentang pemesanan (BVA) | Pilih tanggal H+89 | Diterima — tepi dalam cakrawala 90 hari |
| TC-18 Di luar rentang pemesanan (EP tidak valid) | Pilih tanggal H+90 | Tidak tersedia di kalender |
| TC-19 Penanda kalender hari penuh | Semua slot satu tanggal terisi | Tanggal berlabel "Penuh", tanpa titik ketersediaan |
| TC-20 Penanda kalender masih ada slot | Satu tanggal masih punya slot bebas yang belum lewat | Tanggal bertitik penanda ketersediaan |
| TC-21 Praseleksi dari Cari Slot | Hasil pencarian slot bebas dibuka ke Jadwal | Slot hasil terpilih otomatis **hanya bila** masih bebas saat dibuka |
| TC-22 Laporan hanya menghitung yang disetujui | Campuran booking confirmed/pending/ditolak pada rentang laporan | Pendapatan & okupansi hanya dari booking *confirmed* |
| TC-23 Pengguna biasa membuat booking | Akun non-admin membuat booking lewat aplikasi | Dokumen lahir berstatus *pending*; `isAdmin` pembuat tetap false (dijaga rules) |
| TC-24 Eskalasi admin ditolak (rules) | Pengguna biasa mencoba mengubah `isAdmin` dirinya menjadi true | Ditolak oleh Firestore Security Rules |

## 3. Keterlacakan (Traceability)

- TC-01 s.d. TC-12 → test logika ketersediaan & status slot (`booking_logic`, `availability_logic`).
- TC-13 s.d. TC-16 → test logika seri & verifikasi (`recurring_logic`, `verify_logic`, fungsi murni penyaring daftar individual).
- TC-17 s.d. TC-21 → test logika kalender & praseleksi (`calendar_logic`, `canPreselect`).
- TC-22 → test logika laporan (`report_logic`).
- TC-23 & TC-24 → pengujian security rules pada emulator Firebase (termasuk bukti 5/5 skenario rules pada gerbang rilis v0.4).

Seluruh 24 test case inti di atas adalah bagian dari 170 test otomatis; sisanya mencakup test komponen/visual (token desain, animasi, keadaan layar) yang mengunci perilaku presentasi pada Fase G.
