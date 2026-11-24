import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/incoming_backup_service.dart';
import 'services/locale_service.dart';
import 'services/notify_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tải đồng thời ngôn ngữ và chế độ Sáng/Tối đã lưu
  await LocaleService.instance.loadSavedLocale();
  await ThemeService.instance.loadSavedTheme();
  await NotifyService.instance.init();
  IncomingBackupService.instance.init();

  runApp(const MinExpiryTrackerApp());
}

class MinExpiryTrackerApp extends StatelessWidget {
  const MinExpiryTrackerApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: brightness,
    );

    final borderRadius = BorderRadius.circular(12);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: borderRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder + Listenable.merge lắng nghe cả 2 tín hiệu cùng lúc mà không cần lồng 2 lớp
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleService.instance.localeNotifier,
        ThemeService.instance.themeNotifier,
      ]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: IncomingBackupService.instance.navigatorKey,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          locale: LocaleService.instance.localeNotifier.value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeService.instance.themeNotifier.value,
          home: const HomeScreen(),
        );
      },
    );
  }
}