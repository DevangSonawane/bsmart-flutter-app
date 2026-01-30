import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      primaryColor: DesignTokens.instaPurple,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: DesignTokens.instaPurple,
        secondary: DesignTokens.instaPink,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.instaPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16.0),
        bodyMedium: TextStyle(fontSize: 14.0, color: Colors.black54),
      ),
    );
  }
}

