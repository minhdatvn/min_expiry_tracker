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

  // 1. Chọn màu sắc cảnh báo (hỗ trợ cả đồ theo Giờ và đồ theo Ngày/Tháng)
  Color _getStatusColor() {
    // Trường hợp 1: Đồ ngắn hạn tính PAO theo GIỜ
    if (item.isHourlyPao) {
      final remaining = item.timeRemaining;
      if (remaining.isNegative || remaining.inHours < 3) {
        return Colors.red.shade700;    // Quá hạn hoặc còn dưới 3 giờ -> Đỏ
      }
      if (remaining.inHours < 12) {
        return Colors.orange.shade800; // Còn dưới 12 giờ -> Cam
      }
      return Colors.green.shade700;    // Còn từ 12 giờ trở lên -> Xanh lá
    }

    // Trường hợp 2: Đồ theo NGÀY / THÁNG (giữ nguyên logic cũ)
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

  // 2. Tạo dòng chữ đếm ngược gọn gàng ở nhãn góc phải
  String _getStatusText() {
    // Nếu là đồ tính theo GIỜ -> hiển thị chính xác theo giờ/phút
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

    // Đồ theo NGÀY / THÁNG
    final days = item.daysRemaining;
    if (days < 0) return '${days.abs()}d ago';
    if (days == 0) return 'Today';
    return '${days}d left';
  }

  // 3. Chọn Icon mặc định theo Loại sản phẩm
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

    // Nếu tính theo giờ -> hiện thêm HH:mm (VD: Nov 22, 23:30)
    final formattedDate = item.isHourlyPao
        ? DateFormat('MMM dd, HH:mm').format(item.effectiveExpiryDate)
        : DateFormat('MMM dd, yyyy').format(item.effectiveExpiryDate);

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
              // --- CỘT TRÁI: ẢNH CHỤP HOẶC ICON MẶC ĐỊNH ---
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
                        child: Icon(_getCategoryIcon(), color: statusColor, size: 28),
                      ),
              ),
              const SizedBox(width: 12),

              // --- CỘT GIỮA: TÊN, PHÂN LOẠI, NGÀY/GIỜ HẾT HẠN ---
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
                    const SizedBox(height: 4),
                    Text(
                      [
                        item.category,
                        if (item.quantity != null) 'Qty: ${item.quantity}',
                        if (item.owner != null && item.owner!.isNotEmpty) item.owner!,
                      ].join(' • '),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Exp: $formattedDate',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                              item.paoShortLabel, // Tự hiện PAO 6M, PAO 3D hoặc PAO 4H
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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