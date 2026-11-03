# BDD-03 — Batas horizon
# Deofoot 1.5.0, Pertemuan 11. Flow: maestro/bdd-03-batas-horizon.yaml.
# Status: BELUM TERBUKTI — flow belum dijalankan di perangkat
# (lihat pengujian/06-bdd-integration-usability.md).
#
# Aturan yang diuji (booking_logic.dart bookingDateRange): rentang
# tanggal booking = hari ini s/d H+89 (90 hari). H+90 berada di luar
# rentang. Di UI, kalender sheet hanya memuat hari-hari dalam rentang
# itu, sehingga H+90 tidak tampil sama sekali.
#
# Prasyarat jalan: akun uji sudah dibuat; lapangan Futsal pertama ada.
# CATATAN KEJUJURAN: Maestro tidak bisa menghitung tanggal H+89 pada
# saat jalan (flow bersifat statis), dan nomor tanggal berulang tiap
# bulan sehingga ketuk nomor hari tidak bisa menunjuk H+89 secara
# unik. Karena itu flow ini mengantar pelaksana ke ujung kalender,
# dan konfirmasi batas (tanggal terakhir = hari ini + 89 hari, dan
# tidak ada tanggal sesudahnya) dilakukan pelaksana secara manual
# di perangkat. Jangan mengklaim batas ini lolos dari flow saja.

Feature: Batas horizon booking

  Scenario: H+89 bisa dipilih, H+90 tidak ada
    Given pengguna sudah login dengan akun uji
    When pengguna membuka jadwal lapangan Futsal pertama
    And pengguna membuka kalender lewat "Tanggal main"
    And pengguna menggulir kalender sampai ujung akhir
    Then tanggal terakhir yang tampil adalah hari ini + 89 hari
    And tidak ada tanggal sesudahnya di kalender
    # Bukti lewat apa yang tampil di UI, bukan dari kode.
