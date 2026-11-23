import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/locale_service.dart';
import 'services/notify_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tải đồng thời ngôn ngữ và chế độ Sáng/Tối đã lưu
  await LocaleService.instance.loadSavedLocale();
  await ThemeService.instance.loadSavedTheme();
  await NotifyService.instance.init();

  runApp(const MinExpiryTrackerApp());
}

class MinExpiryTrackerApp extends StatelessWidget {
  const MinExpiryTrackerApp({super.key});

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
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,

          locale: LocaleService.instance.localeNotifier.value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          // Bảng màu Chế độ Sáng
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          // Bảng màu Chế độ Tối (Material 3 tự cân chỉnh độ tương phản dịu mắt)
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          themeMode: ThemeService.instance.themeNotifier.value,
          home: const HomeScreen(),
        );
      },
    );
  }
}