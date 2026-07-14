import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colori principali Cyber-Dark
  static const Color obsidian = Color(0xFF0A0E17);
  static const Color surfaceDark = Color(0xFF161F33);
  static const Color cardBorder = Color(0xFF243354);
  
  // Colori Accento Neon
  static const Color neonCyan = Color(0xFF00F2FE);
  static const Color neonPurple = Color(0xFF9D4EDD);
  static const Color emerald = Color(0xFF00E676);
  static const Color crimson = Color(0xFFFF3B30);
  static const Color amber = Color(0xFFFFB300);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidian,
      primaryColor: neonCyan,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonPurple,
        surface: surfaceDark,
        error: crimson,
        onPrimary: obsidian,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
        bodyMedium: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: neonCyan,
        selectionColor: Color(0x3300F2FE),
        selectionHandleColor: neonCyan,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: obsidian.withValues(alpha: 0.85),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: neonCyan),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: neonCyan,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: obsidian,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder, width: 1.5),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1.2),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surfaceDark),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: cardBorder, width: 1.2),
            ),
          ),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surfaceDark),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: cardBorder, width: 1.2),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: obsidian.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neonCyan, width: 2),
        ),
        labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
        hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13.5),
        floatingLabelStyle: GoogleFonts.outfit(color: neonCyan, fontSize: 14),
      ),
    );
  }
}
