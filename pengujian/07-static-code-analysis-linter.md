# 07 \u2014 Static Code Analysis (Pertemuan 13): Linter

Deofoot 1.5.0 \u00b7 Repo: ayyubi06/final-deofoot-analisispengujiansistem-uts
Branch: `fitur/sonarqube-p13` (dari `main` 0b49e68)
Tanggal jalan: 11 November 2026

## 1. Implementasi linter

- Konfigurasi linter berada di `analysis_options.yaml` pada akar repo.
- Paket aturan yang diaktifkan adalah aturan resmi Flutter:

```yaml
include: package:flutter_lints/flutter.yaml
```

- Cakupan analisis: seluruh kode Dart di `lib/` dan `test/`.
- Dikecualikan sesuai konfigurasi: `build/**`, `android/**`, `ios/**`,
  `web/**`, `windows/**`, `macos/**`, `linux/**`.

## 2. Cara menjalankan

Dari akar proyek:

```bash
flutter analyze
```

## 3. Hasil (11 November 2026)

```text
Analyzing deofoot...
No issues found! (ran in 3.1s)
```

Kode keluar (exit code): 0. Tidak ada error, warning, maupun info
yang dilaporkan penganalisis.

## 4. Pemeriksaan kode tidak terpakai (unused code)

Penganalisis memeriksa diagnostik kode tidak terpakai, antara lain:

- `unused_import`
- `unused_local_variable`
- `unused_element`
- `unused_field`
- `dead_code`

Hasil: **0 temuan** untuk kategori kode tidak terpakai, dan 0 isu
untuk keseluruhan kategori diagnostik.

## 5. Kesimpulan

Linter telah terimplementasi melalui `analysis_options.yaml` dan
telah dijalankan dengan hasil bersih (0 isu).

Bagian berikutnya dari tugas ini (menyusul pada dokumen terpisah):
coverage unit test (`flutter test --coverage`) dan pemindaian
SonarQube melalui SonarCloud.
