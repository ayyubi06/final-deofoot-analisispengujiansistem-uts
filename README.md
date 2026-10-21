# deofoot_mvp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deofoot

Aplikasi booking lapangan (Futsal, Padel, Tenis, Mini Soccer) — Flutter + Firebase.

### Cakupan notifikasi (SPEK-V04 A5)

Notifikasi di aplikasi ini adalah **notifikasi lokal terjadwal** di HP pengguna:

- pengingat batas bayar (20 menit sesudah booking dibuat), dan
- pengingat mulai main (1 jam sebelum jam mulai; untuk langganan rutin hanya pertemuan pertama yang dapat pengingat bayar, dan pengingat main hanya untuk pertemuan dalam 14 hari ke depan).

Perubahan status verifikasi dari admin (disetujui/ditolak) **TIDAK** memunculkan notifikasi — itu membutuhkan push notification server (FCM) yang berada di luar cakupan versi ini.
