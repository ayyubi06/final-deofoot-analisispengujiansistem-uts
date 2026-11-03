# BDD-05 — Seri mingguan
# Deofoot 1.5.0, Pertemuan 11. Flow: maestro/bdd-05-seri-mingguan.yaml.
# Status: BELUM TERBUKTI — flow belum dijalankan di perangkat
# (lihat pengujian/06-bdd-integration-usability.md).
#
# Aturan yang diuji (RecurringScreen + createSeries): seri mingguan
# dibuat all-or-nothing (satu tanggal bentrok → seri tidak jadi),
# SATU bukti bayar untuk seluruh seri, dan satu konfirmasi berlaku
# untuk satu seri dengan satu transaksi. Di UI 1.5.0, seri dibuat
# lewat layar "Langganan Rutin" (tombol ikon ulang di jadwal).
#
# Prasyarat jalan: akun uji sudah dibuat; lapangan Futsal pertama ada.
# BATAS FLOW: sama seperti BDD-01 — tombol "Kirim Langganan" hanya
# aktif bila bukti dipilih, dan pemilih gambar sistem berada di luar
# jangkauan Maestro yang andal. Flow berhenti pada lembar pilih
# bukti. Sifat "satu konfirmasi = satu transaksi" adalah properti
# backend (dokumen seri + pertemuan berbagi seriesId, satu bukti);
# verifikasinya lewat baca-saja dokumen (lihat INT-01), bukan UI.
# Bila flow seri tidak ada di UI 1.5.0, skenario ini TIDAK DAPAT
# DIUJI via UI — tetapi layar "Langganan Rutin" ADA di 1.5.0
# (terverifikasi dari kode), jadi flow ditulis untuk UI tersebut.

Feature: Seri mingguan

  Scenario: Pengguna mengatur seri mingguan dari jadwal
    Given pengguna sudah login dengan akun uji
    When pengguna membuka jadwal lapangan Futsal pertama
    And pengguna membuka "Langganan Rutin"
    Then formulir "Atur seri mingguan" tampil
    And pilihan pertemuan 4× tampil dengan total seri
    And pengguna mengisi nomor WhatsApp aktif yang valid
    And lembar pilih bukti transfer dapat dibuka
    # Titik akhir flow di sini (lihat BATAS FLOW di atas).
    # Langkah berikut HANYA manual, bukan bagian flow Maestro:
    # When pengguna memilih bukti dummy dan menekan Kirim Langganan
    # Then snackbar "Langganan terkirim, menunggu verifikasi." tampil
    # And seluruh pertemuan seri berbagi satu seriesId dan satu bukti
