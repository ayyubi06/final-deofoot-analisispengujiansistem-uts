# 06 — Laporan BDD / Integration / Usability Testing (Pertemuan 11)

Deofoot 1.5.0 · Repo: ayyubi06/final-deofoot-analisispengujiansistem-uts
Branch: `fitur/bdd-integration-usability-p11`
SHA main awal (terverifikasi saat branch dibuat, 29 Okt 2026):
`0b49e686952f900eba219140ae437b3b85692021`
PR draft: [MENUNGGU: tautan PR setelah push — laporan ini diperbarui
dengan commit kedua setelah PR dibuat]

> KEJUJURAN UTAMA: flow Maestro dalam paket ini TIDAK bisa lolos
> utuh di perangkat uji, BUKAN karena aplikasi rusak, melainkan karena
> driver Maestro 2.12.0 tidak melihat teks body aplikasi Flutter ini
> (bukti di §5). Karena itu tiap skenario diuji dengan metode hibrida:
> Maestro menjalankan bagian yang drivernya bisa lihat (login,
> chip, tombol, field), dan langkah isi-body dijalankan langsung
> (adb) lalu diverifikasi lewat dump uiautomator + tangkapan layar
> (yang MELIHAT teks body). Status per skenario di §3 adalah hasil
> perilaku yang benar-benar diamati, bukan klaim lolos Maestro.
> Klaim lolos QA tetap wewenang inka, bukan penulis laporan ini.

## 1. Metode

Mengacu kerangka materi dosen:

- **P11 (TDD & BDD):** BDD = perilaku sistem dari sudut pengguna/
  bisnis, kolaborasi teknis dan non-teknis, bahasa Gherkin
  Given-When-Then. Di paket ini "kode paling sederhana" TIDAK
  ditulis karena larangan mengubah kode produksi: yang dihasilkan
  adalah skenario + flow black-box di atas aplikasi berjalan.
- **P10 (Software Testing in Agile, Crispin dkk 2009):** kategori
  otomasi yang dipakai adalah GUI black-box (Maestro) + verifikasi
  langsung (uiautomator/screenshot) untuk bagian yang driver
  Maestro tidak bisa lihat.
- **P9 (Debugging, Myers dan Pezze & Young):** temuan driver
  Maestro (pohon semantik kosong untuk teks body) dibuktikan
  induktif: hierarki Maestro 67 node hanya berisi jam status bar,
  SEMENTARA dump uiautomator pada saat yang sama memuat semua teks
  body ("Tanggal main", "10.00", "Jadwal", "Rabu, 4 November").
  Hipotesis "aplikasi lambat" dieliminasi: layar sudah settle
  bermenit-menit dan pohon Maestro tetap kosong. Setelah perbaikan
  flow, regression dijalankan (`flutter test` 170/170).

## 2. Keputusan alat (sudah diputuskan pemilik, tidak diubah)

- **DIPAKAI: Maestro** (black-box, flow YAML, tanpa mengubah kode
  aplikasi). Versi: **2.12.0** (Windows dan WSL, sama).
- **Cucumber dipakai sebagai FORMAT, bukan driver:** skenario ditulis
  Gherkin di file `.feature`, langkahnya diimplementasikan di flow
  Maestro YAML.
- **TIDAK DIPAKAI:**
  - Playwright: otomasi browser web; Deofoot tidak punya versi web.
  - Espresso: instrumentation Android native yang mencari Android
    View, sedangkan UI Flutter dirender engine sendiri, bukan
    Android View.
  - Katalon: bisa mobile (berbasis Appium) tapi berat dan berlebihan
    untuk tugas ini.
- **Alat verifikasi pendamping (bukan pengganti Maestro):** `adb
  shell uiautomator dump` (accessibility tree Android — melihat
  semua teks), `adb shell screencap` (piksel layar), `adb shell
  input tap` (ketuk titik untuk elemen yang driver Maestro tidak
  lihat). Dipakai HANYA karena driver Maestro terbukti buta
  terhadap teks body (bukti §5); setiap langkah yang dijalankan
  dengan cara ini dicatat di laporan.

## 3. Tabel keterlacakan

| Skenario | File Gherkin | File flow Maestro | Hasil | Bukti |
|---|---|---|---|---|
| BDD-01 Booking happy path | `features/bdd-01-booking-happy-path.feature` | `maestro/bdd-01-booking-happy-path.yaml` | LULUS (hibrida) | Login s/d lembar bukti terverifikasi; rekaman `bdd01-valid-run.mp4` (134 dtk). Flow berhenti di lembar pilih bukti (sesuai spek). |
| BDD-02 Anti double-booking | `features/bdd-02-anti-double-booking.feature` | `maestro/bdd-02-anti-double-booking.yaml` | LULUS (hibrida) | Slot 10.00 tampil "Menunggu" (booking pending B); ketuk tidak memilih (tanpa ringkasan, tanpa tombol Lanjut). |
| BDD-03 Batas horizon | `features/bdd-03-batas-horizon.feature` | `maestro/bdd-03-batas-horizon.yaml` | LULUS (hibrida) | Kalender berakhir 1 Feb 2027 (= hari ini + 89 hari); 2 Feb 2027 (H+90) tidak ada. |
| BDD-04 Pembatalan | `features/bdd-04-pembatalan.feature` | `maestro/bdd-04-pembatalan.yaml` | LULUS (hibrida) | Booking A 11.00 dibatalkan (> 2 jam sebelum main); pindah Akan datang → Riwayat "Dibatalkan". Sisi negatif ≤ 2 jam TIDAK DAPAT DIUJI (lihat §9). |
| BDD-05 Seri mingguan | `features/bdd-05-seri-mingguan.feature` | `maestro/bdd-05-seri-mingguan.yaml` | LULUS UI, tidak dikirim | Layar "Langganan Rutin" lengkap (4×, 11/18/25 Nov + 2 Des 2026, total Rp480.000, WA, bukti, "Kirim Langganan"). Seri TIDAK dikirim (satu konfirmasi = satu transaksi belum dibuktikan end-to-end). |
| BDD-06 Pending kedaluwarsa | `features/bdd-06-pending-kedaluwarsa.feature` | `maestro/bdd-06-pending-kedaluwarsa.yaml` | BASELINE LULUS, kedaluwarsa BELUM TERBUKTI | Pending segar tampil "Menunggu". Booking B masih "Menunggu" ~37 menit sesudah dibuat (lewat 30 menit spek) — transisi ke "Kedaluwarsa" tidak teramati. |
| INT-01 Integrasi Firestore | `features/int-01-integrasi-firestore.feature` | `maestro/int-01-integrasi-firestore.yaml` | LULUS via round-trip UI | Booking B dan A tertulis lalu terbaca kembali lewat UI (Booking Saya: lapangan, tanggal, jam, harga, status "Menunggu"). Pemeriksaan field dokumen lewat konsol Firebase TIDAK dilakukan (di luar jangkauan run ini). |
| INT-02 Unggah bukti | `features/int-02-unggah-bukti.feature` | `maestro/int-02-unggah-bukti.yaml` | LULUS (hibrida) | "Belum ada bukti transfer" + tombol "Pilih bukti transfer" + lembar "Ambil foto" / "Pilih dari galeri" tampil; gambar dummy bisa dipilih dan pratinjau tampil. Tanpa transfer, tanpa kirim, tanpa verifikasi admin. |
| USA-01 Usability | `features/usa-01-usability.feature` | (manual, tanpa flow) | BELUM DIUJI MANUSIA | Protokol: `pengujian/06-protokol-usability.md`. Belum ada penguji manusia di luar pembuat flow. |

Catatan: "LULUS (hibrida)" berarti perilaku yang diuji terbukti
benar lewat kombinasi Maestro (bagian yang drivernya bisa lihat)
dan verifikasi langsung (dump + screenshot). Flow Maestro murni
TIDAK bisa lolos utuh di perangkat ini karena batasan driver (§5);
itu batasan alat, bukan kegagalan aplikasi.

## 4. Hasil per skenario

- **BDD-01:** LULUS (hibrida). Login A via Maestro (assert
  "Masuk" → tap "Masuk" → Email/Password → titik kirim → assert
  "Deofoot" — semua COMPLETED). Beranda → chip Futsal → kartu
  Lapangan 1 (ketuk titik 50%, 43%) → jadwal 4 Nov 2026 → slot
  10.00 dipilih (hijau, ✓) → ringkasan "1 jam · 10.00–11.00
  Rp120.000" + tombol Lanjut → layar "Booking Lapangan"
  (Ringkasan: Lapangan 1, Rabu 4 Nov 2026, 10.00–11.00, 60 menit,
  Total Rp120.000; Nomor WhatsApp; Pembayaran DANA ke
  085135916995 a.n. AZKAL AZKIA; Bukti transfer) → WA
  081200000000 terisi → hint "Pilih bukti transfer dulu untuk
  mengaktifkan tombol." tampil dan tombol Kirim nonaktif →
  setelah bukti dummy dipilih, hint hilang dan Kirim aktif →
  tap "Pilih bukti transfer" → lembar "Ambil foto" / "Pilih dari
  galeri" tampil. BERHENTI di sini (tidak kirim, sesuai spek).
  Rekaman satu run penuh: `bdd01-valid-run.mp4` (134 dtk).
- **BDD-02:** LULUS (hibrida). Prasyarat: B memegang booking
  pending Lapangan 1, 4 Nov 2026, 10.00–11.00 (dibuat 00:43 WIB,
  "Booking terkirim, menunggu verifikasi."). A membuka jadwal
  yang sama: slot 10.00 tampil latar garis amber + label
  "Menunggu" (sementara slot lain putih "Bebas"); bawah layar
  "Pilih slot bebas untuk melanjutkan" (tanpa tombol Lanjut).
  Ketuk slot 10.00: TIDAK terpilih — tanpa ringkasan "1 jam",
  tanpa tombol Lanjut, prompt tetap. Lapisan transaction
  re-check (`createBooking` melempar "Slot sudah dibooking orang
  lain. Silakan pilih jam lain.") tercakup unit test logika,
  bukan flow. Slot yang diuji PERSIS SAMA; tepi bersentuhan
  bukan bentrok (aturan `isOverlapping`).
- **BDD-03:** LULUS (hibrida). Kalender "Pilih tanggal" dibuka
  dari jadwal; digulir sampai ujung: bulan terakhir **Februari
  2027** hanya berisi tanggal **1** (1 Feb 2027). Hitung: 4 Nov
  2026 + 89 hari = 1 Feb 2027 (26 hari sisa Nov + 31 Des + 31
  Jan + 1 = 89). Tanggal 2 Feb 2027 (H+90) TIDAK ADA di kalender.
  Aturan kode: `bookingDateRange` = hari ini s/d H+89.
- **BDD-04:** LULUS (hibrida, sisi positif). Prasyarat: A
  memegang satu booking pending (Lapangan 1, 4 Nov 2026,
  11.00–12.00, dibuat 00:52 WIB; mulai > 2 jam lagi). Booking
  Saya → "Akan datang" → "Menunggu" → tap "Batalkan" → dialog
  "Batalkan booking?" → "Ya, batalkan" → daftar "Akan datang"
  menjadi "Belum ada booking." dan booking muncul di tab
  "Riwayat" berstatus "Dibatalkan" (Lapangan 1, 2026-11-04,
  11:00). Pesan toast "Booking dibatalkan." adalah SnackBar
  sementara dan tidak tertangkap dump (8 dtk sesudah ketuk);
  perubahan status di daftar adalah bukti yang dipakai. Sisi
  negatif (≤ 2 jam, tombol nonaktif + teks "Tidak bisa
  dibatalkan (≤ 2 jam sebelum mulai).") TIDAK DAPAT DIUJI —
  membuat booking ≤ 2 jam dari sekarang berarti menunggu sampai
  mendekati jam main, tidak aman untuk data uji (lihat §9).
- **BDD-05:** LULUS UI, tidak dikirim. Layar "Langganan Rutin"
  dibuka dari tombol ikon jadwal (bounds [954,147][1080,273]).
  Isi terverifikasi: Lapangan 1; Hari Rabu terpilih; Pertemuan
  pertama Rabu, 11 Nov 2026; Jam mulai 10.00, Durasi 1 jam;
  Pertemuan **4×** terpilih (8×/12× ada); "Setiap Rabu
  10.00–11.00"; "Periode 2026-11-11 s/d 2026-12-02"; Total
  (4 pertemuan) **Rp480.000** (4 × Rp120.000); tanggal seri
  2026-11-11, 2026-11-18, 2026-11-25, 2026-12-02 (4 Rabu
  berurutan); Nomor WhatsApp; "Pembayaran (satu kali untuk
  seluruh seri)"; Bukti transfer; tombol "Kirim Langganan".
  Seri TIDAK dikirim (flow berhenti di lembar bukti seperti
  BDD-01), jadi sifat "satu konfirmasi = satu transaksi" BELUM
  dibuktikan end-to-end; yang terbukti adalah UI dan hitungannya.
  Catatan: pertemuan pertama 11 Nov (bukan 4 Nov) karena seri
  dimulai dari Rabu berikutnya.
- **BDD-06:** BASELINE LULUS, kedaluwarsa BELUM TERBUKTI — dengan
  observasi penting. Booking pending segar A (dibuat 00:52 WIB)
  tampil di Booking Saya → "Akan datang" → chip "Menunggu"
  (bukan "Kedaluwarsa"). Itu membuktikan pending segar tidak
  kedaluwarsa prematur. **Observasi:** booking pending B (dibuat
  3 Nov 2026 ~00:43 WIB) MASIH berstatus "Menunggu" saat dicek
  4 Nov 2026 ~01:20 WIB — sekitar **37 menit** sesudah dibuat,
  melewati batas 30 menit spek — dan baru hilang dari "Akan
  datang" sesudah dibatalkan manual (~01:21 WIB). Jadi transisi
  "Menunggu" → "Kedaluwarsa" TIDAK teramati dalam jendela
  30–37 menit; entah kedaluwarsa ditegakkan oleh job berkala
  (bukan tepat 30:00), atau timer mulai dari titik lain, atau
  status hanya diperbarui saat refresh. Ini observasi untuk
  inka, bukan klaim bug — butuh data bertimestamp untuk
  memastikan.
- **INT-01:** LULUS via round-trip UI. Dua booking uji tertulis
  lewat aplikasi lalu terbaca kembali di Booking Saya dengan
  field yang benar (B: Lapangan 1, 2026-11-04, 10:00–11:00,
  Rp120.000, "Menunggu"; A: sama, 11:00–12:00). Itu membuktikan
  jalur tulis-baca Firestore bekerja end-to-end dari sisi
  aplikasi. Pemeriksaan field dokumen mentah lewat konsol
  Firebase (userId, userEmail, pricePerHour, dst.) TIDAK
  dilakukan — di luar jangkauan run ini, dan dokumen TIDAK
  diubah saat memeriksa.
- **INT-02:** LULUS (hibrida). Lembar bukti: "Belum ada bukti
  transfer" + tombol "Pilih bukti transfer" tampil; tap →
  lembar "Ambil foto" / "Pilih dari galeri". "Pilih dari galeri"
  membuka pemilih foto sistem Android; gambar dummy
  (`bukti-uji-dummy.png`, "BUKTI UJI BDD P11 / Deofoot - dummy,
  bukan transfer asli") bisa dipilih dan pratinjaunya tampil di
  seksi Bukti transfer; tombol Kirim menjadi aktif. TANPA
  transfer uang, TANPA tekan Kirim pada flow ini (pengiriman
  dilakukan terpisah untuk membuat booking prasyarat BDD-02/
  BDD-04, dengan bukti dummy yang sama). Verifikasi admin oleh
  isAdmin (layar "Verifikasi Pembayaran") DI LUAR JANGKAUAN dan
  tidak dibuka flow mana pun.
- **USA-01:** BELUM DIUJI MANUSIA. Protokol + lembar observasi ada
  di `pengujian/06-protokol-usability.md`. Hasil observasi TIDAK
  boleh dikarang; lembar diisi dari pengamatan nyata. Kandidat
  penguji: pemilik (ndoro) — belum dijadwalkan.

## 5. Perintah persis dan ringkasan output

Lingkungan uji (jalur Windows, surat susulan 3 Nov 2026 22:13,
GAS pemilik 22:31):

- Laptop pemilik: Windows, RAM 7,33 GB; AVD `deofoot-qa`
  (Pixel 7, API 34, `hw.ramSize=2048`); emulator 37.2.12.0;
  adb 1.0.41; Maestro Windows 2.12.0 (`C:\maestro`,
  JAVA_HOME `C:\Android\jdk-17`).
- Flutter (WSL): 3.47.6 stable, Dart 3.13.5; JDK Temurin
  17.0.20.1+1; Android SDK `~/Android/Sdk`; RAM WSL 3,5 GB.
- APK debug: `flutter build apk --debug` EXIT 0 —
  app-debug.apk 175.678.354 byte, SHA-256
  `8ad03daa21f2ea661a5fb70a5d93c29c88477e25da70c1ecfb204632f1fa78a6`
  (main HEAD `0b49e68`, sama dengan build 29 Okt 2026 — tidak
  perlu rebuild). Terpasang di emulator (`com.deofoot.app`,
  versionName 1.5.0, versionCode 7) — instal pertama gagal
  `INSTALL_FAILED_VERIFICATION_FAILURE` (verifier timeout saat
  sistem sibuk); perbaikan: tunggu 60 dtk + matikan verifier
  (`package_verifier_enable 0`, `verifier_verify_adb_installs
  0`) → Success.
- `flutter test` (regression, 4 Nov 2026 ~01:05): **170/170
  "All tests passed!"** (branch
  `fitur/bdd-integration-usability-p11`).
- Boot emulator: dua kali boot (boot 1 ~22:41, boot 2 ~23:03);
  keduanya memicu badai ANR "Process/System UI isn't
  responding" (RAM host bebas jatuh 3,06 GB → 0,57 GB; guest
  2,4 GB terpakai / 135 MB bebas; load 9,77). ANR teratasi
  dengan ketuk "Close app" via Maestro sesudah badai reda
  (23:13): System UI restart bersih, layar login tampil utuh.
  Cold start aplikasi ~2 menit; muat data Beranda 30–60 dtk+.

Perintah kunci (semua dijalankan 3–4 Nov 2026, WIB):

```
git fetch uts
git rev-parse uts/main
# → 0b49e686952f900eba219140ae437b3b85692021
git checkout -b fitur/bdd-integration-usability-p11 uts/main
flutter pub get
flutter test            # → 170/170, "All tests passed!"
flutter build apk --debug   # → app-debug.apk, SHA 8ad03daa…fa78a6
maestro --version       # → 2.12.0
adb shell uiautomator dump /sdcard/w-*.xml
adb shell screencap -p /sdcard/shot-*.png
adb shell screenrecord --time-limit 180 /sdcard/bdd01-valid-run.mp4
```

TEMUAN ALAT (penentu, bukti 4 Nov 2026 00:14–00:16):

- Driver Maestro 2.12.0 **tidak melihat teks body** aplikasi
  Flutter ini. Hierarki Maestro saat assert "Tanggal main"
  gagal (run 2026-11-04_001523, step-003, 56.975 byte): 67
  node, HANYA 1 node berteks — jam status bar "12:15".
  Dump uiautomator PADA SAAT YANG SAMA (11.820 byte):
  "Tanggal main" 1×, "10.00" 1×, "Jadwal" 1×, "Rabu, 4
  November" 1×. Teks ADA di accessibility tree Android;
  Maestro tidak membacanya. Yang Maestro BISA lihat: judul
  app bar ("Deofoot"), chip ("Semua", "Futsal"), tombol
  ("Masuk", "Daftar"), hint field ("Email", "Password").
  Yang TIDAK BISA: semua teks body (sapaan, nama lapangan,
  harga, label jadwal, jam slot).
- Properti `timeout:` pada `assertVisible` dan `tapOn`
  DITOLAK Maestro 2.12.0 ("Unknown Property: timeout"); tidak
  ada flag `--timeout` global. Wait default ±14 dtk adalah
  batas keras. Perbaikan: 29 assert ber-`timeout: 30000` di 8
  flow diubah jadi polos (hanya file pengujian, bukan kode
  produksi).
- Bug prefiks login di flow (ditemukan 23:53, diperbaiki
  23:56): flow mengasumsikan form login sudah terbuka sesudah
  `launchApp` — assert "Masuk" lolos karena mencocokkan
  TOMBOL "Masuk" di layar sambutan, lalu tap "Email" gagal.
  Perbaikan: sisip `- tapOn: "Masuk"` sesudah assert pertama
  + tombol kirim jadi ketuk titik (50%, 55%) karena "Masuk"
  muncul 3× di form (judul, tombol kirim, "Masuk dengan
  Google"). Terbukti lolos di run ke-4/5/6.
- `launchApp` cold-start ~2 menit melebihi wait Maestro
  (±14 dtk); salinan runtime menghapus `launchApp` dan
  mengandalkan aplikasi yang sudah hangat.
- Emulator WSL: boot TERBUKTI TIDAK MUNGKIN (tanpa /dev/kvm,
  CPU tanpa vmx/svm; RAM WSL 3,5 GB < minimum 4 GB). Jalur
  Windows dipakai sebagai gantinya (surat susulan + GAS
  pemilik 3 Nov 2026 22:31).

## 6. Daftar file baru/diubah

HANYA pengujian + dokumen (tidak ada file kode produksi yang diubah):

- `features/` (9 file): bdd-01 s/d bdd-06, int-01, int-02, usa-01.
- `maestro/` (8 file): bdd-01 s/d bdd-06, int-01, int-02.
  USA-01 sengaja tanpa flow (manual). Perubahan flow sejak
  penulisan awal: (a) 29 assert `timeout:` → polos; (b) prefiks
  login diperbaiki (tap "Masuk" buka form + tombol kirim titik
  50%, 55%).
- `pengujian/06-bdd-integration-usability.md` (laporan ini).
- `pengujian/06-protokol-usability.md` (protokol + lembar observasi).
- Tautan ke laporan 06 dari dokumen pengujian yang ada: (tidak
  ditambahkan — README pengujian tidak diubah; penambahan tautan
  hanya bila perlu dan tidak mengubah isi dokumen lain).

File yang TIDAK ikut commit: `assets/deofoot-v03-assets.zip`
(untracked peninggalan lama, bukan bagian tugas ini).

Bukti run (disimpan di luar repo, di folder kerja marco):

- Rekaman satu run penuh BDD-01: `bdd01-valid-run.mp4`
  (h264, 1080×2400, 134,16 dtk, 5.054.356 byte, SHA-256
  `59d04e65c2851931b6107d462e20886ce4ec1bf51694697ac14ba0cdda5d1615`).
- Tangkapan layar + dump uiautomator tiap langkah kunci
  (jadwal, slot terpilih, layar booking, lembar bukti, kalender
  ujung, layar seri, Booking Saya B/A, Riwayat "Dibatalkan").
- Log Maestro: `C:\Users\benya\.maestro\tests\2026-11-03_235916`
  (run ke-4), `2026-11-04_000432` (run ke-5),
  `2026-11-04_001152` (run ke-6), `2026-11-04_001523`
  (uji pohon jadwal).

## 7. Data uji

- Akun uji Firebase Auth (dibuat malam run, KHUSUS untuk
  pengujian ini; kredensial TIDAK ada di repo, flow, atau
  laporan — hanya di catatan runtime): A `qa-a@deofoot.test`
  (dibuat 3 Nov 2026 23:23), B `qa-b@deofoot.test` (dibuat
  3 Nov 2026 ~00:32). Keduanya pengguna biasa ("Pengguna",
  bukan admin).
- Nomor WhatsApp di flow: `081200000000` (nomor uji berformat
  valid, bukan nomor asli).
- Gambar bukti: `bukti-uji-dummy.png` (800×600, 5.319 byte,
  teks "BUKTI UJI BDD P11 / Deofoot - dummy, bukan transfer
  asli") di `/sdcard/Pictures/` — dipakai sebagai bukti
  transfer dummy untuk kedua booking uji. TANPA transfer uang
  sungguhan.
- Booking uji yang dibuat:
  - B: Lapangan 1, 2026-11-04, 10:00–11:00, Rp120.000, status
    pending ("Menunggu"), dibuat 3 Nov 2026 ~00:43 WIB.
  - A: Lapangan 1, 2026-11-04, 11:00–12:00, Rp120.000, status
    pending → DIBATALKAN 4 Nov 2026 00:56 WIB (kini
    "Dibatalkan" di Riwayat).
- Pembersihan (SELESAI): kedua booking uji sudah dibatalkan
  manual dan tidak lagi menempati slot. A dibatalkan 00:56 WIB
  (bagian dari BDD-04). B dibatalkan 4 Nov 2026 ~01:21 WIB
  sesudah verifikasi BDD-02 selesai — saat dibatalkan, statusnya
  MASIH "Menunggu" (dicek ~01:20 WIB, ~37 menit sesudah dibuat),
  jadi kedaluwarsa otomatis 30 menit TIDAK terjadi dalam
  jendela itu (lihat BDD-06, §4). "Akan datang" kedua akun kini
  kosong ("Belum ada booking."); Riwayat masing-masing berisi
  satu "Dibatalkan". Akun uji A/B dibiarkan (akun Firebase
  Auth, bukan data booking; tidak menempati slot).
- APK rilis 1.5.0 di HP pemilik: TIDAK disentuh. Pengujian
  memakai APK debug di emulator, bukan HP pemilik.

## 8. Bug nyata yang ditemukan di aplikasi

Tidak ada bug aplikasi yang ditemukan pada skenario yang diuji.
Yang ditemukan adalah dua kekurangan ALAT (bukan aplikasi),
didokumentasikan di §5: (1) driver Maestro 2.12.0 tidak
melihat teks body Flutter; (2) Maestro 2.12.0 menolak properti
`timeout:` per-perintah.

Observasi (bukan bug — dicatat untuk inka/pemilik):

- Badge "N slot bebas hari ini" di Beranda menghitung slot
  bebas tanpa menyaring slot yang sudah lewat (teramati 3 Nov
  2026 23:23: "14 slot bebas hari ini" padahal semua slot
  08.00–22.00 sudah lewat). Perlu dipastikan apakah itu
  disengaja atau tidak — di luar cakupan skenario ini.
- Pesan toast "Booking dibatalkan." hanya tampil sesaat
  (SnackBar); perubahan status di daftar adalah bukti yang
  lebih tahan lama.

## 9. Daftar hal yang belum terbukti

1. Kedaluwarsa pending 30 menit yang sesungguhnya (BDD-06):
   transisi "Menunggu" → "Kedaluwarsa" tidak diamati; booking B
   justru masih "Menunggu" ~37 menit sesudah dibuat.
2. Sisi negatif pembatalan ≤ 2 jam (BDD-04): tombol nonaktif +
   teks "Tidak bisa dibatalkan (≤ 2 jam sebelum mulai)." tidak
   diuji — membuat booking ≤ 2 jam dari sekarang tidak aman
   untuk data uji. Status: TIDAK DAPAT DIUJI pada run ini.
3. Sifat "satu konfirmasi = satu transaksi" untuk seri mingguan
   (BDD-05): seri tidak dikirim, jadi belum dibuktikan
   end-to-end; yang terbukti adalah UI + hitungan (4×
   Rp120.000 = Rp480.000, 4 Rabu berurutan).
4. Pemeriksaan field dokumen Firestore mentah lewat konsol
   (INT-01): hanya round-trip UI yang dibuktikan.
5. Verifikasi admin oleh isAdmin (di luar jangkauan, akun asli
   dilarang).
6. Usability manusia (USA-01): butuh penguji di luar pembuat
   flow.
7. Flow Maestro murni yang lolos utuh: TIDAK MUNGKIN di
   perangkat ini selama driver Maestro buta terhadap teks body.
   Bila inka menjalankan flow Maestro apa adanya, flow akan
   gagal di assert/tap teks body — itu batasan driver, bukan
   kegagalan aplikasi. Jalankan dengan metode hibrida (§2)
   atau di perangkat/driver yang melihat teks body.

## 10. Gerbang setelah laporan ini

Laporan → QA independen inka → persetujuan eksplisit pemilik → baru
PR di-merge (oleh pemilik atau marco atas perintah pemilik).
Penulis laporan TIDAK merge sendiri dan TIDAK mengklaim tugas ini
selesai sebelum inka memeriksa. Output untuk LMS (link commit/MR)
baru dipakai setelah gerbang di atas lolos, kecuali pemilik
memerintahkan lain secara eksplisit.
