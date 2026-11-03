# 06 — Protokol Usability (manual, tidak diotomasi)

Deofoot 1.5.0 · Pertemuan 11 (BDD / Integration / Usability Testing)
Pasangan: `features/usa-01-usability.feature`
Status: **BELUM DIUJI MANUSIA** — belum ada penguji manusia di luar
pembuat flow yang menjalankan protokol ini. Lembar observasi di bawah
diisi dari pengamatan nyata; jangan mengarang hasil.

## 1. Mengapa manual

Sesuai materi P10 (Software Testing in Agile, Crispin dkk 2009):
usability TIDAK bisa diotomasi penuh. Yang diuji di sini adalah
pengalaman pengguna sungguhan — kebingungan, keraguan, dan kesalahan
yang hanya terlihat bila ada manusia yang mengamati manusia lain.
Flow Maestro tidak menggantikan protokol ini.

## 2. Syarat penguji

- Minimal 1 orang di luar pembuat flow (marco).
- Penguji belum pernah memakai Deofoot, atau setidaknya belum pernah
  menyelesaikan booking di dalamnya.
- Penguji memakai perangkat uji (emulator atau HP uji) dengan APK
  debug branch ini dan akun uji khusus — BUKAN HP pemilik, BUKAN
  akun asli, BUKAN akun admin.
- Pengamat mendampingi tanpa membantu (lihat §4).

## 3. Tugas yang diberikan ke penguji

Satu kalimat saja, tanpa panduan langkah demi langkah:

> "Buatlah satu booking untuk bermain minggu ini."

Tidak ada penjelasan tambahan tentang tombol, urutan layar, atau
istilah di aplikasi. Bila penguji bertanya "harus menekan apa?",
jawab: "Coba saja seperti yang menurutmu benar" — dan catat
pertanyaan itu sebagai titik bingung.

## 4. Yang dicatat pengamat

Selama penguji mengerjakan tugas, pengamat mencatat (tanpa intervensi):

| Butir | Cara mencatat |
|---|---|
| Waktu total | Dari aplikasi dibuka sampai formulir booking terkirim atau penguji menyerah (menit:detik). |
| Jumlah kesalahan | Setiap ketukan yang dibatalkan, kembali, atau salah sasaran; setiap isian formulir yang ditolak validasi. |
| Titik bingung | Setiap momen penguji berhenti > 10 detik, bertanya, atau berkata "tidak tahu / tidak jelas". Tulis layar dan teks yang tampil saat itu. |
| Komentar penguji | Ucapan apa adanya, termasuk keluhan dan pujian. Jangan diringkas menjadi "baik". |
| Hasil akhir | Tercapai (booking terkirim) / tidak tercapai (menyerah di layar apa). |

## 5. Kuesioner singkat (sesudah tugas)

Ditanyakan langsung setelah tugas, apa pun hasilnya:

1. Seberapa mudah menyelesaikan booking tadi? (1 = sangat sulit, 5 = sangat mudah)
2. Apakah status bookingmu jelas setelah terkirim? (jelaskan dengan kata-katamu)
3. Bagian mana yang paling membingungkan, dan kenapa?
4. Apa yang kamu ubah dari aplikasi ini bila bisa?

## 6. Lembar observasi (salin per penguji)

```
Tanggal pengujian : (isi saat pengujian nyata)
Penguji           : (nama/inisial, bukan pembuat flow)
Perangkat         : (emulator/HP uji + versi APK debug)
Akun uji          : (email akun uji, BUKAN kata sandi)
Waktu total       : ___ menit ___ detik
Jumlah kesalahan  : ___
Hasil akhir       : tercapai / tidak tercapai (layar terakhir: ___)

Titik bingung:
1. (layar + apa yang terjadi)
2. ...

Komentar penguji (apa adanya):
- ...

Kuesioner:
1. Kemudahan (1-5): ___
2. Kejelasan status: ...
3. Paling membingungkan: ...
4. Yang diubah: ...
```

## 7. Penilaian

Tidak ada nilai lolos/gagal otomatis. Hasil protokol ini dibaca
sebagai temuan: daftar titik bingung dan komentar adalah masukan
perbaikan, bukan vonis. Bila penguji tidak mencapai hasil, itu
temuan usability — bukan kegagalan penguji — dan dicatat apa adanya
di laporan 06.
