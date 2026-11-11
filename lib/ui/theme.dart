import 'package:flutter/material.dart';

/// Google Pixel Material 3 (Material You) Theme Palette for RetroFlux Omni 4.0
/// Adheres strictly to M3 Dark Theme specifications, tonal elevation surfaces, and capsule geometry
class RetroFluxTheme {
  // 1. Material 3 Tonal Surfaces (Deep Neutral & Surface Containers)
  static const Color background = Color(0xFF121316); // Deep neutral surface
  static const Color surface = Color(0xFF121316);
  static const Color surfaceContainerLow = Color(0xFF16181C);
  static const Color surfaceContainer = Color(0xFF1A1C20); // Elevated cards & panels
  static const Color surfaceContainerHigh = Color(0xFF282A2F); // Elevated drop zones & interactive blocks
  static const Color surfaceContainerHighest = Color(0xFF33353A); // Chips & search pills

  // Backward compatibility alias for cards & borders
  static const Color card = Color(0xFF1A1C20);
  static const Color cardHover = Color(0xFF222429);
  static const Color cardBorder = Color(0xFF282A2F); // Soft tonal border
  static const Color cardBorderGlow = Color(0xFF383B42);

  // 2. Material You Primary & Accent Tonal Colors
  static const Color primary = Color(0xFFD0BCFF); // Material You Lavender / Purple
  static const Color onPrimary = Color(0xFF381E72); // Deep purple high-contrast text on primary
  static const Color primaryContainer = Color(0xFF4F378B); // Pill container background for active items
  static const Color onPrimaryContainer = Color(0xFFEADDFF); // Text & icon on active pill

  // Secondary & Tertiary
  static const Color secondaryContainer = Color(0xFF4A4458);
  static const Color onSecondaryContainer = Color(0xFFE8DEF8);
  static const Color tertiaryContainer = Color(0xFF492532);
  static const Color onTertiaryContainer = Color(0xFFFFD8E4);

  // 3. Studio Harmonized Material You Tones (Google Workspace & Pixel Palette)
  // Docs & Office: Google Docs / Drive Pastel Blue & Sheets Emerald
  static const Color docAccent = Color(0xFFA8C7FA);
  static const Color docOfficeBlue = Color(0xFF0842A0);
  static const Color docExcelGreen = Color(0xFF6DD58C);
  static const Color docPptOrange = Color(0xFFFFB784);

  // Media & Video: Pixel Media Pastel Rose
  static const Color mediaAccent = Color(0xFFFFB0CD);
  static const Color mediaGlow = Color(0xFFD946EF);

  // Image Studio: Google Photos Pastel Cyan
  static const Color imageAccent = Color(0xFFA1E3F9);
  static const Color imageGlow = Color(0xFF00F0FF);

  // PRO Tier: Material You Warm Amber
  static const Color proAmber = Color(0xFFFFD966);

  // Compatibility aliases
  static const Color neonCyan = Color(0xFFD0BCFF);
  static const Color neonMagenta = Color(0xFFFFB0CD);
  static const Color neonAmber = Color(0xFFFFD966);
  static const Color neonGreen = Color(0xFF6DD58C);

  // 4. High-Contrast Typography (Google Sans / Roboto)
  static const Color textPrimary = Color(0xFFE2E2E6); // onSurface
  static const Color textSecondary = Color(0xFFC4C6D0); // onSurfaceVariant
  static const Color textMuted = Color(0xFF8E9099); // outline

  // Gradients (Subtle M3 Tonal Gradients)
  static const LinearGradient mediaGradient = LinearGradient(
    colors: [Color(0xFFFFB0CD), Color(0xFFD0BCFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient imageGradient = LinearGradient(
    colors: [Color(0xFFA1E3F9), Color(0xFFD0BCFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient docGradient = LinearGradient(
    colors: [Color(0xFFA8C7FA), Color(0xFF6DD58C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient proBadgeGradient = LinearGradient(
    colors: [Color(0xFFFFD966), Color(0xFFFFB784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      cardColor: surfaceContainer,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: Color(0xFFCCC2DC),
        onSecondary: Color(0xFF332D41),
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
        onSurfaceVariant: textSecondary,
        outline: Color(0xFF48464C),
        outlineVariant: cardBorder,
        error: Color(0xFFF2B8B5),
        onError: Color(0xFF601410),
      ),
      fontFamily: 'Product Sans',
      fontFamilyFallback: const [
        'Google Sans',
        'Google Sans Text',
        'Roboto',
        'Segoe UI',
        'sans-serif',
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: Color(0xFF48464C), width: 1),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceContainer,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }
}
