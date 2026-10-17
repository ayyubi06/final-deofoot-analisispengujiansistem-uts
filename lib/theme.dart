import 'package:flutter/material.dart';

/// Tema Deofoot — light mode saja (sesuai DESAIN-UIUX.md final).
class DeofootTheme {
  static const Color primary = Color(0xFF102A43); // navy pekat
  static const Color accent = Color(0xFFff7a1A); // oranye energik
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF5B6B7F);
  static const Color available = Color(0xFF16A34A); // hijau: slot bebas
  static const Color booked = Color(0xFFCBD5E1); // abu: slot terisi
  static const Color pending = Color(0xFFF59E0B); // amber: menunggu verifikasi
  static const Color danger = Color(0xFFDC2626);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: surface,
      ),
    );
  }

  /// Warna chip status booking.
  static Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return pending;
      case 'confirmed':
        return available;
      case 'rejected':
      case 'cancelled':
        return danger;
      default:
        return textMuted;
    }
  }

  /// Label Indonesia untuk status booking.
  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }
}
