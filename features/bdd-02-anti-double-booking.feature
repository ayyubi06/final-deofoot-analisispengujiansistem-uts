# BDD-02 — Anti double-booking
# Deofoot 1.5.0, Pertemuan 11. Flow: maestro/bdd-02-anti-double-booking.yaml.
# Status: BELUM TERBUKTI — flow belum dijalankan di perangkat
# (lihat pengujian/06-bdd-integration-usability.md).
#
# Aturan yang diuji (booking_logic.dart): overlap = m1 < s2 && m2 < s1;
# status cancelled/rejected/expired diabaikan; tepi yang bersentuhan
# (end == start) BUKAN bentrok. Yang diuji di sini adalah slot yang
# PERSIS SAMA, bukan slot bersebelahan.
#
# Prasyarat jalan:
# - Akun uji A (pelaksana flow) dan akun uji B sudah dibuat.
# - Slot 10.00 hari ini pada lapangan Futsal pertama SUDAH ditempati
#   booking pending milik akun uji B (data uji, bukan data asli).
#   Bila slot yang ditempati berbeda, sesuaikan jam di flow dan
#   catat di laporan.
# - Lapisan kedua (transaction re-check di createBooking yang melempar
#   "Slot sudah dibooking orang lain. Silakan pilih jam lain.") TIDAK
#   bisa dicapai lewat UI karena grid sudah memblokir slot terisi;
#   lapisan itu tercakup unit test logika, bukan flow ini.

Feature: Anti double-booking

  Scenario: Slot yang persis sama tidak bisa dipilih pengguna lain
    Given satu slot 10.00 hari ini sudah dibooking (status pending)
    And pengguna lain sudah login dengan akun uji
    When pengguna lain membuka jadwal lapangan yang sama
    Then slot 10.00 tampil sebagai "Menunggu"
    When pengguna lain mengetuk slot 10.00
    Then tidak terjadi seleksi (tetap tampil "Pilih slot bebas untuk melanjutkan")
    And tombol "Lanjut" tidak muncul
    # Artinya: tidak ada booking ganda yang bisa dibuat dari UI
    # untuk slot yang persis sama. Slot bersebelahan (mis. 11.00)
    # tetap bebas dipilih karena tepinya hanya bersentuhan.
