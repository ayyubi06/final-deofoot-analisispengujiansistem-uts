# INT-01 — Integrasi aplikasi-Firestore
# Deofoot 1.5.0, Pertemuan 11. Flow UI: maestro/int-01-integrasi-firestore.yaml.
# Status: BELUM TERBUKTI — flow belum dijalankan di perangkat dan
# pemeriksaan dokumen belum dilakukan (lihat laporan 06).
#
# Yang diuji: booking yang dibuat lewat UI harus muncul sebagai
# dokumen booking di koleksi "bookings" dengan field yang benar:
# fieldId, fieldName, date (yyyy-MM-dd), startTime/endTime (HH:mm),
# status "pending", totalPrice, pricePerHour, userId, userEmail.
# (Kolom persis mengikuti createBooking di firestore_service.dart.)
#
# CARA VERIFIKASI (baca-saja, tanpa mengubah data):
# 1. Selesaikan satu booking secara manual di perangkat uji dengan
#    akun uji (langkah manual yang sama seperti ujung BDD-01).
# 2. Buka Firebase console / jalankan query Firestore baca-saja:
#    koleksi "bookings", filter userId = UID akun uji, urutkan dari
#    terbaru. JANGAN mengubah, menghapus, atau menulis dokumen apa pun.
# 3. Cocokkan field dokumen dengan ringkasan yang tampil di UI.
# Maestro TIDAK bisa mengkueri Firestore; bagian ini manual dan
# dicatat sebagai langkah manual di laporan, bukan diklaim dari flow.

Feature: Integrasi aplikasi-Firestore

  Scenario: Booking dari UI tercatat benar di Firestore
    Given pengguna sudah login dengan akun uji
    And pengguna menyelesaikan satu booking lewat UI
    When pemeriksa membaca dokumen booking terbaru akun uji (baca-saja)
    Then fieldId, fieldName, date, startTime, endTime cocok dengan UI
    And status dokumen adalah "pending"
    And totalPrice sama dengan harga di ringkasan UI
