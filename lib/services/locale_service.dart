import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';

class LocaleService {
  static final LocaleService instance = LocaleService._init();
  LocaleService._init();

  final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);

  // MỚI: Xác định ngôn ngữ đang thực sự hiển thị (kể cả khi đang để "Theo điện thoại")
  Locale get effectiveLocale {
    final code = localeNotifier.value?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'vi' ? const Locale('vi') : const Locale('en');
  }

  // MỚI: Lấy thẳng bộ từ điển mà không cần BuildContext (dùng cho NotifyService & CalendarService)
  AppLocalizations get currentL10n => lookupAppLocalizations(effectiveLocale);

  Future<File> _getPrefFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_locale.txt');
  }

  Future<void> loadSavedLocale() async {
    try {
      final file = await _getPrefFile();
      if (!await file.exists()) return;

      final code = (await file.readAsString()).trim();
      if (code == 'en' || code == 'vi') {
        localeNotifier.value = Locale(code);
      } else {
        localeNotifier.value = null;
      }
    } catch (_) {
      localeNotifier.value = null;
    }
  }

  Future<void> setLocale(String? languageCode) async {
    localeNotifier.value =
        languageCode == null ? null : Locale(languageCode);

    try {
      final file = await _getPrefFile();
      await file.writeAsString(languageCode ?? '');
    } catch (_) {}
  }
}