# BDD-01 — Booking happy path
# Deofoot 1.5.0, Pertemuan 11 (BDD & Integration Testing).
# Gaya: Gherkin Given-When-Then persis materi P11.
# Flow pelaksana: maestro/bdd-01-booking-happy-path.yaml (1-ke-1).
# Status: BELUM TERBUKTI — flow belum dijalankan di perangkat
# (lihat pengujian/06-bdd-integration-usability.md). Tidak ada
# klaim lolos di dokumen ini.
#
# Prasyarat jalan:
# - Aplikasi terpasang dari APK debug branch ini, kondisi fresh
#   (belum login) atau sesi sudah logout.
# - Akun uji khusus sudah dibuat di Firebase Auth (BUKAN akun asli,
#   BUKAN akun admin). Kredensial diisi pelaksana di flow, bukan
#   di dokumen ini.
# - Lapangan Futsal pertama bertarif Rp120.000/jam dan slot 10.00
#   hari ini bebas. Bila slot 10.00 terisi, ganti dengan slot bebas
#   lain dan catat perubahannya di laporan.
#
# BATAS FLOW (jujur, sesuai spek): tombol "Kirim Booking" hanya aktif
# bila bukti transfer dipilih, dan memilih bukti membuka pemilih
# gambar sistem (di luar jangkauan Maestro yang andal) serta akan
# membuat booking pending di Firestore produksi. Karena itu flow
# ini berhenti pada titik terakhir yang bisa diverifikasi di dalam
# aplikasi (formulir lengkap + lembar pilih bukti tampil). Bagian
# "booking berstatus pending dan tampil di daftar" baru terbukti
# setelah pengiriman diselesaikan manual di perangkat uji dan
# diverifikasi lewat INT-01. Jangan mengklaim BDD-01 lolos sebelum
# itu terjadi.

Feature: Booking happy path

  Scenario: Pengguna membuat booking slot kosong 60 menit
    Given pengguna sudah login dengan akun uji
    When pengguna memilih lapangan Futsal pertama
    And pengguna memilih slot kosong 10.00 hari ini
    And pengguna menekan Lanjut ke formulir booking
    Then formulir "Booking Lapangan" tampil dengan ringkasan yang benar
    And pengguna mengisi nomor WhatsApp aktif yang valid
    And lembar pilih bukti transfer dapat dibuka
    # Titik akhir flow di sini (lihat BATAS FLOW di atas).
    # Langkah berikut HANYA manual, bukan bagian flow Maestro:
    # When pengguna memilih bukti dummy dan menekan Kirim Booking
    # Then layar "Booking terkirim, menunggu verifikasi." tampil
    # And booking berstatus pending tampil di "Booking Saya"
