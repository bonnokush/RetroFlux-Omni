import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/theme_controller.dart';
import 'ui/adaptive_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop Window Ergonomics Configuration
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1150, 750),
        minimumSize: Size(700, 500),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'RetroFlux Omni 4.0 PRO - Universal File Converter',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('Window manager initialization warning: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: RetroFluxOmniApp(),
    ),
  );
}

class RetroFluxOmniApp extends ConsumerWidget {
  const RetroFluxOmniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeControllerProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final darkColorScheme =
            themeSettings.useSystemWallpaper ? darkDynamic : null;
        final lightColorScheme =
            themeSettings.useSystemWallpaper ? lightDynamic : null;

        final darkTheme = ThemeController.buildTheme(
          seedColor: themeSettings.seedColor,
          brightness: Brightness.dark,
          dynamicColorScheme: darkColorScheme,
        );

        final lightTheme = ThemeController.buildTheme(
          seedColor: themeSettings.seedColor,
          brightness: Brightness.light,
          dynamicColorScheme: lightColorScheme,
        );

        return MaterialApp(
          title: 'RetroFlux Omni 4.0 PRO',
          debugShowCheckedModeBanner: false,
          themeMode: themeSettings.themeMode,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: const AdaptiveScaffold(),
        );
      },
    );
  }
}
