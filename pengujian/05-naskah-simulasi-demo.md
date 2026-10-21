# Naskah Simulasi Tes — Demonstrasi UTS Deofoot

*Simulasi pengujian empat lapis yang didemonstrasikan pada waktu UTS. Tulang punggungnya adalah rekaman; demo langsung dilakukan bila waktu memungkinkan. Setiap lapis menunjuk ke dokumennya di folder ini.*

## Lapis 1 — Unit & Widget Test Otomatis (±2 menit)

**Yang ditunjukkan:** terminal menjalankan `flutter test` pada repositori ini; seluruh suite berakhir hijau: **170/170 lulus**.

**Narasi:** "Test case dirancang dengan format Slide 14 — setiap baris punya input dan expected output (dokumen 02). Tekniknya equivalence partitioning dan boundary value: misalnya slot yang bersentuhan tepinya *tidak* dianggap bentrok, pending kedaluwarsa tepat di menit ke-30, dan pembatalan tepat di batas 2 jam."

**Bila ditanya:** tunjukkan satu berkas test (mis. test rentang 90 hari: H+89 diterima, H+90 ditolak).

## Lapis 2 — System Testing di Aplikasi (±4 menit)

**Skenario yang didemokan berurutan** (sesuai ST-01 s.d. ST-04, dokumen 04):

1. Login sebagai pengguna → Beranda → pilih Lapangan Futsal 1.
2. Buka Jadwal → ketuk field tanggal → kalender terbuka: tunjukkan penanda ketersediaan (titik = masih ada slot, label "Penuh").
3. Pilih slot bebas → buat booking → unggah bukti transfer → status *pending*.
4. Coba pesan slot yang sama dari akun kedua → **tertolak** (anti double booking).
5. Buat langganan seri singkat → tunjukkan total = jumlah pertemuan × tarif.
6. Masuk sebagai admin → Verifikasi: booking individual dan kartu seri tampil terpisah → buka **Rincian Seri** → periksa bukti → **Terima satu kali** → seluruh pertemuan terkonfirmasi.

**Narasi kunci:** "Konfirmasi langganan adalah satu keputusan utuh per seri — bukan per pertemuan. Itu keputusan desain yang kami kunci sesudah menemukan risiko keputusan parsial pada pengujian versi sebelumnya."

## Lapis 3 — Acceptance Testing (±1 menit)

**Yang ditunjukkan:** daftar gerbang rilis (dokumen 04 Bagian 2) dan buktinya: verdict QA independen, hash APK terverifikasi, nomor versi 1.5.0 terbaca dari manifes.

**Narasi:** "Produk dinyatakan layak rilis bukan oleh pengembangnya, melainkan oleh gerbang: suite hijau, QA independen menyatakan LULUS, artefak terverifikasi, dan uji langsung di perangkat oleh pemilik project. Versi 0.4 kami pernah ditolak di gerbang ini dan harus diperbaiki dulu — gerbangnya nyata."

## Lapis 4 — Regression Testing (±2 menit)

**Yang ditunjukkan:** tabel pertumbuhan suite 43 → 104 → 113 → 150 → 170 (dokumen 04) dan tabel klasifikasi test obsolete/redundant.

**Narasi:** "Perubahan terbesar kami adalah desain ulang total. Regression testing membuktikan fungsi tidak ikut berubah: seluruh berkas logika terbukti byte-identik dengan versi sebelumnya; satu-satunya perbedaan logika adalah rentang pemesanan 90 hari yang memang keputusan resmi. Test yang mengunci perilaku lama — misalnya pertemuan seri tampil individual — kami klasifikasikan *obsolete* dan diganti, bukan dihapus diam-diam."

## Antisipasi Pertanyaan

| Pertanyaan | Jawaban Singkat |
|---|---|
| Kenapa pembayaran masih manual? | Keputusan cakupan MVP: verifikasi manusia oleh satu admin lebih sederhana & aman untuk skala ini; gateway pembayaran masuk daftar pengembangan lanjutan. |
| Bagaimana mencegah double booking? | Status slot dihitung dari seluruh booking pada tanggal itu; tumpang tindih ditentukan oleh `mulai1 < selesai2 && mulai2 < selesai1`; slot pending ikut menahan slot; ditegakkan juga oleh desain test TC-02 s.d. TC-06. |
| Kenapa notifikasi belum push (FCM)? | Keterbatasan paket Firebase gratis (Spark) dan cakupan: notifikasi lokal cukup untuk pengingat jadwal; keterbatasannya dinyatakan terbuka di aplikasi. |
| Apa kelemahan sistem saat ini? | Lihat evaluasi ISO 25010 (dokumen 03): kompatibilitas & portabilitas bernilai Cukup (Android saja) dan daftar booking terbaca pengguna login — keduanya keputusan sadar yang terdokumentasi beserta rekomendasinya. |
| Bagaimana regression dijaga saat desain berubah total? | Batas keras selama desain ulang: logika dan model data dibekukan; QA membuktikan ekuivalensi di tingkat berkas, bukan sekadar menjalankan aplikasi. |
