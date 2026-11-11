import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 6 Vibrant Google Pixel Material You Seed Color Presets
class PixelSeeds {
  static const Color cyberBlue = Color(0xFF2979FF); // Electric Pixel Bay Blue
  static const Color emeraldMint = Color(0xFF00E676); // Vivid Emerald / Mint
  static const Color electricViolet = Color(0xFF8B5CF6); // Vibrant Radiant Violet
  static const Color sunburstCoral = Color(0xFFFF5722); // Punchy Sunset Coral
  static const Color solarAmber = Color(0xFFFFB300); // Radiant Golden Amber
  static const Color neonCyan = Color(0xFF00E5FF); // Cyberpunk Neon Cyan

  // Backwards-compatible aliases
  static const Color bayBlue = cyberBlue;
  static const Color obsidianLavender = electricViolet;
  static const Color sageGreen = emeraldMint;
  static const Color terracottaCoral = sunburstCoral;
  static const Color amberGold = solarAmber;

  static const List<Map<String, dynamic>> all = [
    {'name': 'Cyber Blue', 'color': cyberBlue},
    {'name': 'Emerald Mint', 'color': emeraldMint},
    {'name': 'Electric Violet', 'color': electricViolet},
    {'name': 'Sunburst Coral', 'color': sunburstCoral},
    {'name': 'Solar Amber', 'color': solarAmber},
    {'name': 'Neon Cyan', 'color': neonCyan},
  ];
}

class ThemeSettings {
  final Color seedColor;
  final ThemeMode themeMode;
  final bool useSystemWallpaper;

  const ThemeSettings({
    this.seedColor = PixelSeeds.cyberBlue,
    this.themeMode = ThemeMode.dark,
    this.useSystemWallpaper = false,
  });

  ThemeSettings copyWith({
    Color? seedColor,
    ThemeMode? themeMode,
    bool? useSystemWallpaper,
  }) {
    return ThemeSettings(
      seedColor: seedColor ?? this.seedColor,
      themeMode: themeMode ?? this.themeMode,
      useSystemWallpaper: useSystemWallpaper ?? this.useSystemWallpaper,
    );
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeSettings>((ref) {
  return ThemeController();
});

class ThemeController extends StateNotifier<ThemeSettings> {
  static const String _prefSeedKey = 'm3_seed_color_val';
  static const String _prefModeKey = 'm3_theme_mode_val';
  static const String _prefSysWallKey = 'm3_use_system_wallpaper';

  ThemeController() : super(const ThemeSettings()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seedVal = prefs.getInt(_prefSeedKey);
      final modeVal = prefs.getString(_prefModeKey);
      final sysWall = prefs.getBool(_prefSysWallKey) ?? false;

      Color seed = PixelSeeds.cyberBlue;
      if (seedVal != null) {
        seed = Color(seedVal);
      }

      ThemeMode mode = ThemeMode.dark;
      if (modeVal == 'light') mode = ThemeMode.light;
      if (modeVal == 'system') mode = ThemeMode.system;

      state = ThemeSettings(
        seedColor: seed,
        themeMode: mode,
        useSystemWallpaper: sysWall,
      );
    } catch (_) {}
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color, useSystemWallpaper: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSeedKey, color.value);
    await prefs.setBool(_prefSysWallKey, false);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefModeKey, mode.name);
  }

  Future<void> toggleSystemWallpaper(bool enabled) async {
    state = state.copyWith(useSystemWallpaper: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSysWallKey, enabled);
  }

  /// Builds a compliant Material 3 ThemeData from dynamic or preset seed
  static ThemeData buildTheme({
    required Color seedColor,
    required Brightness brightness,
    ColorScheme? dynamicColorScheme,
  }) {
    final baseColorScheme = dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        );

    // Dynamic Material You tinted surfaces for true OLED/Dark depth
    final colorScheme = brightness == Brightness.dark
        ? () {
            const surfaceBase = Color(0xFF0D0F13);
            final accent = baseColorScheme.primary;
            return baseColorScheme.copyWith(
              surface: Color.alphaBlend(accent.withOpacity(0.04), surfaceBase),
              surfaceContainerLow:
                  Color.alphaBlend(accent.withOpacity(0.07), surfaceBase),
              surfaceContainer:
                  Color.alphaBlend(accent.withOpacity(0.11), surfaceBase),
              surfaceContainerHigh:
                  Color.alphaBlend(accent.withOpacity(0.16), surfaceBase),
              surfaceContainerHighest:
                  Color.alphaBlend(accent.withOpacity(0.22), surfaceBase),
              outlineVariant: Color.alphaBlend(
                  accent.withOpacity(0.16), const Color(0xFF1E2128)),
            );
          }()
        : baseColorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardColor: colorScheme.surfaceContainer,
      fontFamily: 'Product Sans',
      fontFamilyFallback: const [
        'Google Sans',
        'Google Sans Text',
        'Roboto',
        'Segoe UI',
        'sans-serif',
      ],
      dividerTheme: const DividerThemeData(
        thickness: 0,
        space: 0,
        color: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }
}
