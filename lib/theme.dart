import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema Deofoot — Fase G "Pitch" (SPEK-DESAIN-FASE-G §1).
///
/// Token spek tersedia dengan nama persisnya (pitch900, pitch700,
/// pitch500, volt, surfacePitch, card, ink60, line, amber, red,
/// grey). Nama token lama dipertahankan sebagai alias bernilai
/// Pitch supaya seluruh layar lama tetap terkompilasi — peran tiap
/// alias sama seperti sebelumnya, hanya nilainya yang berganti
/// palet. Status selalu warna + label teks (pola v0.4).
class DeofootTheme {
  // --- Token Pitch (SPEK-DESAIN-FASE-G §1.1) ---
  static const Color pitch900 = Color(0xFF0A231B); // teks utama
  static const Color pitch700 = Color(0xFF0E5C40); // primer
  static const Color pitch500 = Color(0xFF12805A); // aksen sekunder
  static const Color volt = Color(0xFFC6F135); // aksen hidup
  static const Color surfacePitch = Color(0xFFF6F4EE); // latar layar
  static const Color card = Color(0xFFFFFFFF); // permukaan kartu
  static const Color ink60 = Color(0xFF5A6B63); // teks sekunder
  static const Color line = Color(0xFFE4E1D8); // garis tipis
  static const Color amber = Color(0xFFD98E04); // status Menunggu
  static const Color red = Color(0xFFD64545); // Ditolak/destruktif
  static const Color grey = Color(0xFF8A948E); // Batal/Kedaluwarsa/terisi

  // --- Alias peran lama -> nilai Pitch ---
  static const Color primary = pitch700;
  static const Color accent = pitch500;
  static const Color background = surfacePitch;
  static const Color surface = card;
  static const Color textMuted = ink60;
  static const Color available = pitch700;
  static const Color booked = grey;
  static const Color pastSlot = line;
  static const Color pending = amber;
  static const Color danger = red;

  // --- Bentuk (§1.3): radius konsentris & bayangan lembut ---
  static const double radiusCard = 20;
  static const double radiusSheet = 24;
  static const double radiusChip = 999;
  static const double radiusSlot = 12;
  static const double radiusButton = 14;

  /// Bayangan dua lapis (ambient + key) warna pitch900 opasitas
  /// rendah — pengganti garis keras pada kartu.
  static List<BoxShadow> get cardShadows => [
        BoxShadow(
          color: pitch900.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: pitch900.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  // --- Tipografi (§1.2): Plus Jakarta Sans + angka tabular ---
  static TextStyle get displayStyle => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        height: 34 / 28,
        fontWeight: FontWeight.w700,
        color: pitch900,
      );

  static TextStyle get titleStyle => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        color: pitch900,
      );

  static TextStyle get bodyStyle => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        height: 22 / 15,
        color: pitch900,
      );

  static TextStyle get captionStyle => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        height: 16 / 12,
        color: ink60,
      );

  /// Terapkan tabular figures: angka tidak bergeser saat berubah
  /// (syarat number ticker yang rapi, §1.2).
  static TextStyle tabular(TextStyle style) => style.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: pitch700,
      primary: pitch700,
      secondary: pitch500,
      surface: card,
    );
    final jakarta = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfacePitch,
      textTheme: jakarta.copyWith(
        headlineMedium: displayStyle,
        titleLarge: titleStyle,
        bodyMedium: bodyStyle,
        bodySmall: captionStyle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfacePitch,
        foregroundColor: pitch900,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: card,
        shadowColor: pitch900.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pitch700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: pitch700),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusChip),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: card,
      ),
    );
  }

  /// Warna chip status booking (§1.1: Dibatalkan/Kedaluwarsa =
  /// grey; selalu disertai label teks dari [statusLabel]).
  static Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return amber;
      case 'confirmed':
        return pitch700;
      case 'rejected':
        return red;
      case 'cancelled':
      case 'expired':
        return grey;
      default:
        return ink60;
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
      case 'expired':
        return 'Kedaluwarsa';
      default:
        return status;
    }
  }
}
