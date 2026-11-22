import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../widgets/item_card.dart';

// StatefulWidget: Dùng khi màn hình CÓ sự thay đổi giao diện theo thao tác người dùng
// (ví dụ: bấm chọn bộ lọc Medicine, Cosmetics -> danh sách vẽ lại ngay lập tức).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Danh mục đang được chọn để lọc (mặc định là "All")
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Medicine',
    'Cosmetics',
    'Food',
    'Other',
  ];

  // Dữ liệu mẫu (Mock Data) để chạy thử giao diện trước khi gắn SQLite
  final List<HouseholdItem> _items = [
    HouseholdItem(
      id: 1,
      name: 'Vitamin C Serum',
      category: 'Cosmetics',
      expiryDate: DateTime.now().add(const Duration(days: 200)),
      openedDate: DateTime.now().subtract(const Duration(days: 175)),
      paoMonths: 6, // Mở nắp gần 6 tháng -> PAO sẽ đến trước HSD bao bì!
      quantity: 1,
      owner: 'Me',
      alertDays: [30, 7],
    ),
    HouseholdItem(
      id: 2,
      name: 'Paracetamol 500mg',
      category: 'Medicine',
      expiryDate: DateTime.now().add(const Duration(days: 20)),
      quantity: 2,
      owner: 'Family',
      alertDays: [60, 14], // Cảnh báo sớm hơn dành riêng cho thuốc
    ),
    HouseholdItem(
      id: 3,
      name: 'Fresh Oat Milk',
      category: 'Food',
      expiryDate: DateTime.now().subtract(const Duration(days: 2)), // Đã quá hạn 2 ngày
      quantity: 1,
      alertDays: [3, 1],
    ),
    HouseholdItem(
      id: 4,
      name: 'Sunscreen SPF 50+',
      category: 'Cosmetics',
      expiryDate: DateTime.now().add(const Duration(days: 120)),
      owner: 'Me',
      alertDays: [30, 7],
    ),
  ];

  // Lọc theo danh mục đang chọn và sắp xếp món nào sắp hết hạn lên đầu
  List<HouseholdItem> get _filteredItems {
    final filtered = _selectedCategory == 'All'
        ? List<HouseholdItem>.from(_items)
        : _items.where((item) => item.category == _selectedCategory).toList();

    // Sắp xếp tăng dần theo số ngày còn lại (số âm/số nhỏ lên trên cùng)
    filtered.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _filteredItems;

    // Scaffold là "bộ khung" chuẩn của một màn hình Android (gồm AppBar, Body, Nút +)
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MinExpiryTracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Nút Cài đặt (sẽ dùng cho Backup/Restore và Đổi ngôn ngữ sau này)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings & Backup coming soon!')),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // --- 1. THANH LỌC DANH MỤC (CUỘN NGANG) ---
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    // setState báo cho Flutter biết dữ liệu đã đổi -> hãy vẽ lại màn hình!
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              },
            ),
          ),

          // --- 2. DANH SÁCH VẬT PHẨM ---
          Expanded(
            child: displayItems.isEmpty
                // Nếu danh mục không có món nào -> hiện thông báo thân thiện
                ? Center(
                    child: Text(
                      'No items in $_selectedCategory yet.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                  )
                // ListView.builder chỉ vẽ những thẻ đang nằm trong tầm mắt -> siêu mượt trên Android!
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: displayItems.length,
                    itemBuilder: (context, index) {
                      final item = displayItems[index];
                      return ItemCard(
                        item: item,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Tapped on ${item.name}')),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),

      // --- 3. NÚT THÊM VẬT PHẨM MỚI ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Item screen coming in next step!')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}
