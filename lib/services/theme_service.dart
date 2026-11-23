import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThemeService {
  static final ThemeService instance = ThemeService._init();
  ThemeService._init();

  // Mặc định theo cài đặt Sáng/Tối của điện thoại
  final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  Future<File> _getPrefFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_theme.txt');
  }

  Future<void> loadSavedTheme() async {
    try {
      final file = await _getPrefFile();
      if (!await file.exists()) return;

      final value = (await file.readAsString()).trim();
      switch (value) {
        case 'light':
          themeNotifier.value = ThemeMode.light;
          break;
        case 'dark':
          themeNotifier.value = ThemeMode.dark;
          break;
        default:
          themeNotifier.value = ThemeMode.system;
      }
    } catch (_) {
      themeNotifier.value = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    try {
      final file = await _getPrefFile();
      await file.writeAsString(mode.name); // Ghi 'system', 'light', hoặc 'dark'
    } catch (_) {}
  }
}