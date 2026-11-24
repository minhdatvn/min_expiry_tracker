import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/backup_service.dart';
import '../services/locale_service.dart';
import '../services/notify_service.dart';
import '../services/theme_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static String? _cachedVersion;
  bool _isBusy = false;
  String _appVersion = _cachedVersion ?? '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    if (_cachedVersion != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final formatted = info.buildNumber.isNotEmpty
          ? '${info.version} (${info.buildNumber})'
          : info.version;
      _cachedVersion = formatted;
      if (!mounted) return;
      setState(() => _appVersion = formatted);
    } catch (_) {
      // Bỏ qua êm ái nếu không đọc được thông tin gói
    }
  }

  // Lấy tên hiển thị của ngôn ngữ đang chọn
  String _getCurrentLanguageLabel(AppLocalizations l10n, Locale? locale) {
    switch (locale?.languageCode) {
      case 'en':
        return l10n.languageEnglish;
      case 'vi':
        return l10n.languageVietnamese;
      default:
        return l10n.languageSystem;
    }
  }

  // Mở bảng trượt từ đáy lên để chọn ngôn ngữ & tự đồng bộ lại ngôn ngữ thông báo đã hẹn
  void _showLanguageSheet() {
    final l10n = AppLocalizations.of(context)!;
    final currentCode = LocaleService.instance.localeNotifier.value?.languageCode;

    final options = <(String?, String)>[
      (null, l10n.languageSystem),
      ('en', l10n.languageEnglish),
      ('vi', l10n.languageVietnamese),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final primaryColor = Theme.of(context).colorScheme.primary;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.languageTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ...options.map((opt) {
                final code = opt.$1;
                final label = opt.$2;
                final isSelected = currentCode == code;

                return ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? primaryColor : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: primaryColor)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    if (code == currentCode) return;

                    // So sánh ngôn ngữ hiển thị thực tế trước và sau khi đổi
                    final oldEffective = LocaleService.instance.effectiveLocale;
                    await LocaleService.instance.setLocale(code);
                    final newEffective = LocaleService.instance.effectiveLocale;

                    if (oldEffective != newEffective) {
                      if (mounted) setState(() => _isBusy = true);
                      try {
                        await NotifyService.instance.rescheduleAllAlerts();
                      } finally {
                        if (mounted) setState(() => _isBusy = false);
                      }
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _getCurrentThemeLabel(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
      case ThemeMode.system:
        return l10n.themeSystem;
    }
  }

  void _showThemeSheet() {
    final l10n = AppLocalizations.of(context)!;
    final currentMode = ThemeService.instance.themeNotifier.value;

    final options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, l10n.themeSystem, Icons.brightness_auto_outlined),
      (ThemeMode.light, l10n.themeLight, Icons.light_mode_outlined),
      (ThemeMode.dark, l10n.themeDark, Icons.dark_mode_outlined),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.themeTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ...options.map((opt) {
              final mode = opt.$1;
              final label = opt.$2;
              final icon = opt.$3;
              final isSelected = currentMode == mode;

              return ListTile(
                leading: Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await ThemeService.instance.setThemeMode(mode);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Xử lý khi bấm nút Sao lưu
  Future<void> _handleBackup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isBusy = true);
    try {
      final count = await BackupService.instance.exportBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupReady(count))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // Xử lý khi bấm nút Khôi phục
  Future<void> _handleRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreDialogTitle),
        content: Text(l10n.restoreDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.chooseFile),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      final restoredCount = await BackupService.instance.importBackup();
      if (!mounted) return;

      if (restoredCount != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.restoreSuccess(restoredCount)),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.restoreError),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionTitleColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = LocaleService.instance.localeNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            if (_isBusy) const LinearProgressIndicator(),

            // --- KHU VỰC 1: NGÔN NGỮ ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.languageSection,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: sectionTitleColor,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(l10n.languageTitle),
              subtitle: Text(_getCurrentLanguageLabel(l10n, currentLocale)),
              trailing: const Icon(Icons.chevron_right),
              enabled: !_isBusy,
              onTap: _showLanguageSheet,
            ),

            const Divider(height: 24),

            // --- KHU VỰC 2: GIAO DIỆN ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l10n.appearanceSection,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: sectionTitleColor,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(l10n.themeTitle),
              subtitle: Text(
                _getCurrentThemeLabel(
                  l10n,
                  ThemeService.instance.themeNotifier.value,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              enabled: !_isBusy,
              onTap: _showThemeSheet,
            ),

            const Divider(height: 24),

            // --- KHU VỰC 3: DỮ LIỆU & SAO LƯU ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l10n.dataAndBackup,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: sectionTitleColor,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(l10n.backupData),
              subtitle: Text(l10n.backupSubtitle),
              enabled: !_isBusy,
              onTap: _handleBackup,
            ),

            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: Text(l10n.restoreData),
              subtitle: Text(l10n.restoreSubtitle),
              enabled: !_isBusy,
              onTap: _handleRestore,
            ),

            const Divider(height: 24),

            // --- KHU VỰC 4: THÔNG TIN ỨNG DỤNG ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l10n.aboutSection,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: sectionTitleColor,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.appTitle),
              subtitle: Text(
                l10n.versionSubtitle(_appVersion.isEmpty ? '...' : _appVersion),
              ),
            ),
          ],
        ),
      ),
    );
  }
}