# USA-01 — Usability (MANUAL, tidak diotomasi)
# Deofoot 1.5.0, Pertemuan 11. TIDAK ada flow Maestro untuk skenario
# ini — sesuai materi P10, usability TIDAK bisa diotomasi penuh:
# butuh mata, telinga, dan kecerdasan manusia yang mengamati
# pengguna sungguhan. Pelaksanaannya mengikuti protokol di
# pengujian/06-protokol-usability.md.
#
# Status: BELUM DIUJI MANUSIA — belum ada penguji manusia di luar
# pembuat flow yang menjalankan protokol ini. Jangan mengarang hasil
# observasi; lembar observasi diisi dari pengamatan nyata.

Feature: Usability booking tanpa panduan

  Scenario: Pengguna baru menyelesaikan satu booking tanpa panduan
    Given penguji manusia (bukan pembuat flow) memegang perangkat uji
    And penguji sudah login dengan akun uji
    And penguji TIDAK diberi panduan langkah demi langkah
    When penguji diminta "Buatlah satu booking untuk bermain minggu ini"
    Then penguji mencapai formulir booking tanpa bantuan
    And waktu, jumlah kesalahan, titik bingung, dan komentar dicatat
    And penguji mengisi kuesioner singkat (kemudahan, kejelasan status)
    # Hasil dicatat apa adanya, termasuk kegagalan dan titik bingung.
