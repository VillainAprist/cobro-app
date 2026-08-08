import 'package:flutter/material.dart';

class AppTheme {

  // Colores Principales
  static const Color primary = Color(0xFF1E3A8A); // Azul Cobalto Profundo
  static const Color primaryAccent = Color(0xFF2563EB); // Azul Vibrante
  static const Color background = Color(0xFF0F172A); // Slate Muy Oscuro
  static const Color cardBg = Color(0xFF1E293B); // Slate Oscuro para Tarjetas
  static const Color cardBgLight = Color(0xFF334155);

  // Estados de Préstamo
  static const Color success = Color(0xFF10B981); // Emerald Green - Pagado
  static const Color warning = Color(0xFFF59E0B); // Amber Gold - Pendiente
  static const Color danger = Color(0xFFEF4444);  // Crimson Red - Vencido

  // Textos y Subtítulos
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAccent,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        surface: cardBg,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBgLight.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
    );
  }
}
