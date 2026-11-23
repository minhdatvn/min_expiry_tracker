import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/locale_service.dart';
import 'services/notify_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tải ngôn ngữ người dùng đã chọn từ lần mở trước
  await LocaleService.instance.loadSavedLocale();

  // Khởi động hệ thống thông báo offline
  await NotifyService.instance.init();

  runApp(const MinExpiryTrackerApp());
}

class MinExpiryTrackerApp extends StatelessWidget {
  const MinExpiryTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder tự vẽ lại toàn bộ app ngay khi người dùng đổi ngôn ngữ
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleService.instance.localeNotifier,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,

          // Cấu hình đa ngôn ngữ (tự nối cả từ điển của bạn lẫn hộp thoại Lịch/Giờ gốc Android)
          locale: currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}