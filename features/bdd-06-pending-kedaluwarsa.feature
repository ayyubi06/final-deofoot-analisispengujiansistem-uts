# BDD-06 — Pending kedaluwarsa 30 menit
# Deofoot 1.5.0, Pertemuan 11. Flow: maestro/bdd-06-pending-kedaluwarsa.yaml.
# Status: BELUM TERBUKTI — flow belum dijalankan di perangkat
# (lihat pengujian/06-bdd-integration-usability.md).
#
# Aturan yang diuji: booking pending yang basi (> 30 menit) menjadi
# kedaluwarsa (expireStalePendings berjalan saat aplikasi dibuka dan
# saat jadwal dibuka; status menjadi "Kedaluwarsa" dan slot kembali
# bebas).
#
# KEJUJURAN: flow ini TIDAK menunggu 30 menit real-time sebagai
# syarat lolos, sesuai spek. Yang bisa dibuktikan flow di sini
# hanyalah baseline: booking pending yang masih segar tetap tampil
# "Menunggu" (tidak kedaluwarsa prematur) sesudah aplikasi dibuka.
# Pembuktian kedaluwarsa yang sesungguhnya membutuhkan data uji
# bertimestamp (booking pending yang dibuat > 30 menit lalu di
# proyek uji) — bila data itu tidak tersedia, status skenario ini
# tetap BELUM TERBUKTI, bukan lolos dan bukan gagal.

Feature: Pending kedaluwarsa

  Scenario: Booking pending segar tidak kedaluwarsa prematur
    Given pengguna sudah login dengan akun uji
    And pengguna memiliki booking pending yang masih segar
    When pengguna membuka "Booking Saya"
    Then booking tersebut tampil dengan status "Menunggu"
    # Bukan "Kedaluwarsa".

  Scenario: Booking pending basi menjadi kedaluwarsa (butuh data bertimestamp)
    Given pengguna memiliki booking pending yang dibuat > 30 menit lalu
    When pengguna membuka kembali aplikasi
    Then booking tersebut berstatus "Kedaluwarsa"
    And slotnya kembali bebas di jadwal
    # Skenario ini HANYA bisa dijalankan bila data uji bertimestamp
    # tersedia. Tanpa itu: BELUM TERBUKTI.
