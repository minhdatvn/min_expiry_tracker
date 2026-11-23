import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class LocaleService {
  static final LocaleService instance = LocaleService._init();
  LocaleService._init();

  // ValueNotifier đóng vai trò như "loa thông báo":
  // - null: dùng ngôn ngữ mặc định theo điện thoại
  // - Locale('en') hoặc Locale('vi'): ép hiển thị Tiếng Anh / Tiếng Việt
  final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);

  // Đường dẫn file text nhỏ lưu lựa chọn ngôn ngữ trong thư mục riêng của app
  Future<File> _getPrefFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_locale.txt');
  }

  // Đọc lại ngôn ngữ đã lưu mỗi khi mở app (chạy 1 lần trong main.dart)
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

  // Đổi ngôn ngữ và lưu xuống máy (truyền null nếu chọn "Theo điện thoại")
  Future<void> setLocale(String? languageCode) async {
    localeNotifier.value =
        languageCode == null ? null : Locale(languageCode);

    try {
      final file = await _getPrefFile();
      await file.writeAsString(languageCode ?? '');
    } catch (_) {
      // Nếu ghi file gặp lỗi thì giao diện vẫn đổi được trong phiên hiện tại
    }
  }
}