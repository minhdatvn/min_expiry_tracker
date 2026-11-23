import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';

class ItemCard extends StatelessWidget {
  final HouseholdItem item;
  final VoidCallback? onTap;

  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  // 1. Chọn màu sắc cảnh báo
  Color _getStatusColor() {
    if (item.isHourlyPao) {
      final remaining = item.timeRemaining;
      if (remaining.isNegative || remaining.inHours < 3) {
        return Colors.red.shade700;
      }
      if (remaining.inHours < 12) {
        return Colors.orange.shade800;
      }
      return Colors.green.shade700;
    }

    final days = item.daysRemaining;
    if (days <= 0) return Colors.red.shade700;

    if (item.alertDays.isNotEmpty) {
      final sortedAlerts = List<int>.from(item.alertDays)..sort();
      if (sortedAlerts.length >= 2 && days <= sortedAlerts.first) {
        return Colors.red.shade600;
      }
      if (days <= sortedAlerts.last) {
        return Colors.orange.shade800;
      }
    }

    return Colors.green.shade700;
  }

  // 2. Nhãn đếm ngược góc phải
  String _getStatusText() {
    if (item.isHourlyPao) {
      final remaining = item.timeRemaining;
      final absMinutes = remaining.inMinutes.abs();
      final absHours = remaining.inHours.abs();

      if (remaining.isNegative) {
        if (absMinutes < 60) return '${absMinutes}m ago';
        return '${absHours}h ago';
      } else {
        if (absMinutes < 60) return '${absMinutes}m left';
        return '${absHours}h left';
      }
    }

    final days = item.daysRemaining;
    if (days < 0) return '${days.abs()}d ago';
    if (days == 0) return 'Today';
    return '${days}d left';
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
    final statusColor = _getStatusColor();
    final formattedDate = item.isHourlyPao
        ? DateFormat('MMM dd, HH:mm').format(item.effectiveExpiryDate)
        : DateFormat('MMM dd, yyyy').format(item.effectiveExpiryDate);

    // Kiểm tra xem vật phẩm này có mốc nào đang đồng bộ với Lịch điện thoại không
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // --- CỘT TRÁI: ẢNH HOẶC ICON ---
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.imageBytes != null
                    ? Image.memory(
                        item.imageBytes!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
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

                    // Loại • Số lượng • Chủ sở hữu • Vị trí
                    Text(
                      [
                        item.category,
                        if (item.quantity != null) 'Qty: ${item.quantity}',
                        if (item.owner != null && item.owner!.isNotEmpty)
                          item.owner!,
                        if (item.location != null && item.location!.isNotEmpty)
                          item.location!,
                      ].join(' • '),
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Ngày hết hạn + nhãn PAO + icon đồng bộ Lịch
                    Row(
                      children: [
                        Icon(
                          item.isHourlyPao
                              ? Icons.access_time
                              : Icons.event_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Exp: $formattedDate',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
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
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.paoShortLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                        if (hasCalendarSync) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.calendar_month,
                            size: 14,
                            color: Colors.purple.shade600,
                          ),
                        ],
                      ],
                    ),

                    // MỚI: Hiển thị trích đoạn 1 dòng nếu món đồ có Ghi chú
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.notes_outlined,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.notes!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
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
                  _getStatusText(),
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