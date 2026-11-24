import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';

class ItemCard extends StatelessWidget {
  final HouseholdItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
  });

  // 1. Chọn màu sắc cảnh báo (nhận thêm biến isDark để tự chỉnh độ sáng ở Chế độ tối)
  Color _getStatusColor(bool isDark) {
    final redCritical = isDark ? Colors.red.shade300 : Colors.red.shade700;
    final redSoon = isDark ? Colors.red.shade300 : Colors.red.shade600;
    final orangeWarn = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
    final greenSafe = isDark ? Colors.green.shade300 : Colors.green.shade700;

    if (item.isHourlyPao) {
      final remaining = item.timeRemaining;
      if (remaining.isNegative || remaining.inHours < 3) {
        return redCritical;
      }
      if (remaining.inHours < 12) {
        return orangeWarn;
      }
      return greenSafe;
    }

    final days = item.daysRemaining;
    if (item.isExpired || item.isExpiringToday) return redCritical;

    if (item.alertDays.isNotEmpty) {
      final sortedAlerts = List<int>.from(item.alertDays)..sort();
      if (sortedAlerts.length >= 2 && days <= sortedAlerts.first) {
        return redSoon;
      }
      if (days <= sortedAlerts.last) {
        return orangeWarn;
      }
    }

    return greenSafe;
  }

  /// 2. Nhãn đếm ngược góc phải (song ngữ, tự gom theo Năm / Tháng / Ngày)
  String _getStatusText(AppLocalizations l10n) {
    if (item.isHourlyPao) {
      final remaining = item.timeRemaining;
      final absMinutes = remaining.inMinutes.abs();
      final absHours = remaining.inHours.abs();

      if (remaining.isNegative) {
        if (absMinutes < 60) return l10n.minutesAgo(absMinutes);
        return l10n.hoursAgo(absHours);
      } else {
        if (absMinutes < 60) return l10n.minutesLeft(absMinutes);
        return l10n.hoursLeft(absHours);
      }
    }

    final days = item.daysRemaining;
    if (days == 0) return l10n.today;

    final absDays = days.abs();
    if (days < 0) {
      if (absDays >= 366) return l10n.moreThanYearsAgo(absDays ~/ 365);
      if (absDays >= 31) return l10n.monthsAgo(absDays ~/ 30);
      return l10n.daysAgo(absDays);
    }

    if (days >= 366) return l10n.moreThanYearsLeft(days ~/ 365);
    if (days >= 31) return l10n.monthsLeft(days ~/ 30);
    return l10n.daysLeft(days);
  }

  // 3. Icon mặc định theo danh mục
  IconData _getCategoryIcon() {
    switch (item.category) {
      case 'Medicine':
        return Icons.medication_outlined;
      case 'Cosmetics':
        return Icons.face_retouching_natural;
      case 'Food':
        return Icons.restaurant_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(isDark);
    final imageBytes = item.imageBytes; // Lấy 1 lần duy nhất từ bộ nhớ đệm
    final formattedDate = formatDateByLocale(
      context,
      item.effectiveExpiryDate,
      includeTime: item.isHourlyPao,
    );

    final hasCalendarSync = item.alerts.any((a) => a.addToCalendar);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withAlpha(70), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // --- CỘT TRÁI: ẢNH HOẶC ICON ---
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes,
                        width: 56,
                        height: 56,
                        // Nén ảnh trong RAM khớp đúng ô 56x56 (tỉ lệ màn hình 3x = 168px)
                        cacheWidth: 168,
                        fit: BoxFit.cover,
                        // Giữ nguyên khung hình cũ khi vẽ lại -> không bị chớp trắng
                        gaplessPlayback: true,
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: statusColor.withAlpha(25),
                        child: Icon(
                          _getCategoryIcon(),
                          color: statusColor,
                          size: 28,
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // --- CỘT GIỮA: TÊN, PHỤ ĐỀ, VỊ TRÍ, NGÀY HẾT HẠN, GHI CHÚ ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    Text(
                      [
                        localizeCategory(l10n, item.category),
                        if (item.quantity != null)
                          l10n.qtyLabel(item.quantity!),
                        if (item.owner != null && item.owner!.isNotEmpty)
                          localizeOwner(l10n, item.owner!),
                        if (item.location != null && item.location!.isNotEmpty)
                          localizeLocation(l10n, item.location!),
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(
                          item.isHourlyPao
                              ? Icons.access_time
                              : Icons.event_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.expLabel(formattedDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.hasPao) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.paoShortLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                // Cặp màu đi liền với secondaryContainer -> luôn rõ nét ở cả Sáng & Tối
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                        if (hasCalendarSync) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.calendar_month,
                            size: 14,
                            color: isDark
                                ? Colors.purple.shade300
                                : Colors.purple.shade600,
                          ),
                        ],
                      ],
                    ),

                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.notes_outlined,
                            size: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.notes!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // --- CỘT PHẢI: NHÃN ĐẾM NGƯỢC ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(l10n),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}