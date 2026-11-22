import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/database_service.dart';
import '../services/notify_service.dart';
import '../widgets/item_card.dart';
import 'add_edit_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Danh mục đang chọn để lọc (mặc định là hiển thị tất cả)
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Medicine',
    'Cosmetics',
    'Food',
    'Other',
  ];

  // Danh sách vật phẩm thật đọc từ SQLite
  List<HouseholdItem> _items = [];
  // Biến đánh dấu trạng thái đang tải dữ liệu để hiện vòng xoay loading
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Vừa mở màn hình lên là gọi SQLite tải dữ liệu ngay
    _loadItems();
  }

  // Đọc toàn bộ vật phẩm từ cơ sở dữ liệu offline
  Future<void> _loadItems() async {
    final items = await DatabaseService.instance.getAllItems();

    // Kiểm tra màn hình còn đang mở không trước khi cập nhật giao diện
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  // Lọc theo danh mục và tự động sắp xếp món sắp hết hạn lên đầu
  List<HouseholdItem> get _filteredItems {
    final filtered = _selectedCategory == 'All'
        ? List<HouseholdItem>.from(_items)
        : _items.where((item) => item.category == _selectedCategory).toList();

    filtered.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return filtered;
  }

  // Mở màn hình Thêm/Sửa và đồng bộ cả SQLite lẫn Lịch thông báo
  Future<void> _openAddEditScreen({HouseholdItem? existingItem}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditScreen(existingItem: existingItem),
      ),
    );

    // Người dùng bấm nút Back không lưu gì -> thoát
    if (result == null) return;

    if (result == 'delete' && existingItem?.id != null) {
      // Xóa trong SQLite + Hủy toàn bộ lịch nhắc của món đó
      await DatabaseService.instance.deleteItem(existingItem!.id!);
      await NotifyService.instance.cancelItemAlerts(existingItem.id!);
    } else if (result is HouseholdItem) {
      if (existingItem == null) {
        // Thêm mới -> lấy mã ID mới do SQLite cấp -> đặt lịch nhắc
        final newId = await DatabaseService.instance.insertItem(result);
        await NotifyService.instance.scheduleItemAlerts(
          result,
          overrideId: newId,
        );
      } else {
        // Chỉnh sửa -> lưu SQLite -> tự động hủy lịch cũ và đặt lịch mới
        await DatabaseService.instance.updateItem(result);
        await NotifyService.instance.scheduleItemAlerts(result);
      }
    }

    // Tải lại danh sách mới nhất từ SQLite để hiển thị
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MinExpiryTracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Nút chuông để kiểm tra nhanh hệ thống thông báo trên Android
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test Notification',
            onPressed: () {
              NotifyService.instance.showTestNotification();
            },
          ),
          // Nút Cài đặt (Backup & Restore)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              // Khi quay lại từ Settings, tải lại danh sách (phòng trường hợp vừa Restore)
              await _loadItems();
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
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              },
            ),
          ),

          // --- 2. DANH SÁCH VẬT PHẨM TỪ SQLITE ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _items.isEmpty
                                ? 'No items yet.\nTap "+ Add Item" to track your first item!'
                                : 'No items in $_selectedCategory.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 80),
                        itemCount: displayItems.length,
                        itemBuilder: (context, index) {
                          final item = displayItems[index];
                          return ItemCard(
                            item: item,
                            onTap: () => _openAddEditScreen(existingItem: item),
                          );
                        },
                      ),
          ),
        ],
      ),

      // --- 3. NÚT THÊM VẬT PHẨM MỚI ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditScreen(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}
