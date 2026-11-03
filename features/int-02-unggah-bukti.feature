# INT-02 — Unggah bukti
# Deofoot 1.5.0, Pertemuan 11. Flow: maestro/int-02-unggah-bukti.yaml.
# Status: BELUM TERBUKTI — flow belum dijalankan di perangkat
# (lihat pengujian/06-bdd-integration-usability.md).
#
# Yang diuji: alur HANYA sampai layar unggah bukti tampil dan file
# dummy bisa dipilih. TANPA transfer uang sungguhan, TANPA memakai
# nomor/akun DANA asli, TANPA menekan Kirim Booking.
#
# DI LUAR JANGKAUAN (dicatat, bukan diuji):
# - Verifikasi admin oleh isAdmin (layar "Verifikasi Pembayaran")
#   TIDAK diuji dengan akun asli dan TIDAK dibuka oleh flow mana pun.
# - Memilih file dari galeri sistem berada di luar jangkauan Maestro
#   yang andal; flow berhenti pada lembar pilih ("Ambil foto" /
#   "Pilih dari galeri" tampil).

Feature: Unggah bukti transfer

  Scenario: Layar unggah bukti tampil dan siap dipilih
    Given pengguna sudah login dengan akun uji
    When pengguna membuka formulir booking untuk slot kosong
    And pengguna mengisi nomor WhatsApp aktif yang valid
    Then langkah "Bukti transfer" tampil dengan "Belum ada bukti transfer"
    And tombol "Pilih bukti transfer" tampil dan aktif
    When pengguna menekan "Pilih bukti transfer"
    Then lembar pilih tampil dengan "Ambil foto" dan "Pilih dari galeri"
    # Berhenti di sini: tanpa transfer, tanpa kirim, tanpa verifikasi admin.
