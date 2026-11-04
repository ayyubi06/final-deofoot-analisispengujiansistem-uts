# BDD-04 — Pembatalan
# Deofoot 1.5.0, Pertemuan 11. Flow: maestro/bdd-04-pembatalan.yaml.
# Status: BELUM TERBUKTI — flow belum dijalankan di perangkat
# (lihat pengujian/06-bdd-integration-usability.md).
#
# Aturan yang diuji (models.dart canCancel): booking masih bisa
# dibatalkan bila status pending/confirmed DAN mulai mainnya lebih
# dari 2 jam lagi. Tombol "Batalkan" nonaktif bila tidak memenuhi
# syarat, dan kartu menampilkan "Tidak bisa dibatalkan
# (≤ 2 jam sebelum mulai)."
#
# Prasyarat jalan:
# - Akun uji sudah dibuat dan memiliki TEPAT SATU booking akan datang
#   yang bisa dibatalkan (bukan seri, mulai main > 2 jam lagi).
#   Flow mengetuk tombol "Batalkan" pertama yang tampil; bila kartu
#   pertama bukan yang bisa dibatalkan, flow gagal dengan keras
#   (bukan lolos palsu) — perbaiki data uji, jangan ubah flow diam-diam.
# - Sisi negatif (pembatalan ≤ 2 jam) HANYA diuji bila bisa dilakukan
#   aman dengan data uji. Bila tidak aman, catat sebagai
#   TIDAK DAPAT DIUJI di laporan, bukan lolos.

Feature: Pembatalan booking

  Scenario: Booking lebih dari 2 jam sebelum main bisa dibatalkan
    Given pengguna sudah login dengan akun uji
    And pengguna memiliki booking akan datang yang bisa dibatalkan
    When pengguna membuka "Booking Saya"
    And pengguna menekan "Batalkan" pada booking tersebut
    And pengguna menekan "Ya, batalkan" pada dialog konfirmasi
    Then snackbar "Booking dibatalkan." tampil
    And booking tersebut tidak lagi tampil di "Akan datang"

  Scenario: Pembatalan 2 jam ke bawah (kondisional, data uji aman saja)
    Given pengguna memiliki booking yang mulainya 2 jam ke bawah lagi
    When pengguna membuka "Booking Saya"
    Then tombol "Batalkan" pada booking tersebut nonaktif
    And tampil "Tidak bisa dibatalkan (≤ 2 jam sebelum mulai)."
    # Bila skenario ini tidak bisa dibuat aman dengan data uji,
    # statusnya TIDAK DAPAT DIUJI — lihat laporan 06.
