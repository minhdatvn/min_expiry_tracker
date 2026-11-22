import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';

// StatelessWidget: Dùng cho những thành phần chỉ nhận dữ liệu và vẽ ra màn hình,
// không tự thay đổi trạng thái bên trong nó.
class ItemCard extends StatelessWidget {
  final HouseholdItem item;
  final VoidCallback? onTap; // Hàm sẽ chạy khi người dùng bấm vào thẻ

  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  // 1. Chọn màu sắc cảnh báo dựa theo mốc cảnh báo RIÊNG (alertDays) của từng vật phẩm
  Color _getStatusColor() {
    final days = item.daysRemaining;

    // Đã hết hạn hoặc hết hạn ngay hôm nay -> Đỏ
    if (days <= 0) return Colors.red.shade700;

    // Nếu vật phẩm có cài mốc cảnh báo
    if (item.alertDays.isNotEmpty) {
      // Sắp xếp các mốc từ nhỏ đến lớn (VD: [30, 7] -> [7, 30])
      final sortedAlerts = List<int>.from(item.alertDays)..sort();

      // Nếu có từ 2 mốc trở lên và rơi vào mốc sát nhất (VD: <= 7 ngày) -> Đỏ
      if (sortedAlerts.length >= 2 && days <= sortedAlerts.first) {
        return Colors.red.shade600;
      }
      // Nếu nằm trong mốc cảnh báo xa nhất (VD: <= 30 ngày) -> Cam/Vàng đậm
      if (days <= sortedAlerts.last) {
        return Colors.orange.shade800;
      }
    }

    // Các trường hợp còn lại là an toàn -> Xanh lá
    return Colors.green.shade700;
  }

  // 2. Tạo dòng chữ hiển thị trạng thái ngắn gọn trên nhãn góc phải
  String _getStatusText() {
    final days = item.daysRemaining;
    if (days < 0) return '${days.abs()}d ago'; // VD: 3d ago (quá hạn 3 ngày)
    if (days == 0) return 'Today';            // Hết hạn hôm nay
    return '${days}d left';                   // VD: 12d left
  }

  // 3. Chọn Icon mặc định theo Loại sản phẩm (dùng khi người dùng không chụp ảnh)
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
    final formattedDate = DateFormat('MMM dd, yyyy').format(item.effectiveExpiryDate);
    final hasPao = item.openedDate != null && item.paoMonths != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        // Viền mỏng cùng tông màu trạng thái để dễ nhận diện nhanh
        side: BorderSide(color: statusColor.withAlpha(70), width: 1),
      ),
      child: InkWell(
        // InkWell tạo hiệu ứng gợn sóng chuẩn Android khi chạm vào thẻ
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
                    // Nếu có ảnh Base64 đã lưu -> vẽ thẳng từ bộ nhớ RAM
                    ? Image.memory(
                        item.imageBytes!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    // Nếu không có ảnh -> hiện ô vuông chứa icon theo loại
                    : Container(
                        width: 56,
                        height: 56,
                        color: statusColor.withAlpha(25),
                        child: Icon(_getCategoryIcon(), color: statusColor, size: 28),
                      ),
              ),
              const SizedBox(width: 12),

              // --- CỘT GIỮA: TÊN, PHÂN LOẠI, NGÀY HẾT HẠN ---
              // Expanded giúp cột giữa chiếm hết khoảng trống còn lại, tránh lỗi tràn chữ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên vật phẩm
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis, // Quá dài sẽ hiện dấu "..."
                    ),
                    const SizedBox(height: 4),

                    // Dòng thông tin phụ: Loại • Số lượng • Người dùng (chỉ hiện nếu có nhập)
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

                    // Ngày hết hạn thực tế (kèm nhãn PAO nếu đã mở nắp)
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Exp: $formattedDate',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (hasPao) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PAO ${item.paoMonths}M',
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

              // --- CỘT PHẢI: NHÃN ĐẾM NGƯỢC SỐ NGÀY ---
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
