// lib/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1D9E75);
  static const Color primaryDark = Color(0xFF0F6E56);
  static const Color primaryLight = Color(0xFF5DCAA5);
  static const Color background = Color(0xFFF0FAF5);
  static const Color cardBg = Colors.white;
  static const Color border = Color(0xFF9FE1CB);
  static const Color textDark = Color(0xFF085041);
  static const Color textMid = Color(0xFF0F6E56);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primary,
    scaffoldBackgroundColor: background,
    fontFamily: 'Nunito',
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}