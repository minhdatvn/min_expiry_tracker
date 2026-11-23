import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/calendar_service.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';
import '../services/notify_service.dart';
import '../widgets/item_card.dart';
import 'add_edit_screen.dart';
import 'log_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  String _selectedOwner = 'All'; // MỚI: Bộ lọc theo Chủ sở hữu

  final List<String> _categories = [
    'All',
    'Medicine',
    'Cosmetics',
    'Food',
    'Other',
  ];

  List<HouseholdItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  // Tạo danh sách các nút lọc Chủ sở hữu tự động từ dữ liệu đang có
  List<String> get _ownerFilterOptions {
    final owners = _items
        .map((e) => e.owner?.trim() ?? '')
        .where((o) => o.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final hasUnassigned = _items.any(
      (e) => e.owner == null || e.owner!.trim().isEmpty,
    );

    return [
      'All',
      ...owners,
      if (hasUnassigned && owners.isNotEmpty) 'Unassigned',
    ];
  }

  Future<void> _loadItems() async {
    final items = await DatabaseService.instance.getAllItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
      // Nếu chủ sở hữu đang lọc không còn món nào nữa thì quay về 'All'
      if (_selectedOwner != 'All' &&
          !_ownerFilterOptions.contains(_selectedOwner)) {
        _selectedOwner = 'All';
      }
    });
  }

  // Lọc kết hợp cả Danh mục + Chủ sở hữu, sau đó sắp xếp theo độ khẩn cấp
  List<HouseholdItem> get _filteredItems {
    final filtered = _items.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;

      final ownerName = item.owner?.trim() ?? '';
      final bool matchesOwner;
      if (_selectedOwner == 'All') {
        matchesOwner = true;
      } else if (_selectedOwner == 'Unassigned') {
        matchesOwner = ownerName.isEmpty;
      } else {
        matchesOwner = ownerName == _selectedOwner;
      }

      return matchesCategory && matchesOwner;
    }).toList();

    filtered.sort((a, b) => a.timeRemaining.compareTo(b.timeRemaining));
    return filtered;
  }

  // MỚI: Bảng Thống kê theo Chủ sở hữu (bấm vào từng người để lọc nhanh luôn!)
  void _showOwnerStatsSheet() {
    final Map<String, List<HouseholdItem>> grouped = {};
    for (final item in _items) {
      final key = (item.owner == null || item.owner!.trim().isEmpty)
          ? 'Unassigned'
          : item.owner!.trim();
      grouped.putIfAbsent(key, () => []).add(item);
    }

    // Sắp xếp người có nhiều vật phẩm nhất lên trên
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Owner Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: ${_items.length} items',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tap any owner to filter your list.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (sortedEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No items to summarize yet.')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedEntries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = sortedEntries[index];
                      final ownerName = entry.key;
                      final ownerItems = entry.value;

                      final expiredCount = ownerItems
                          .where((i) => i.timeRemaining.isNegative)
                          .length;
                      final soonCount = ownerItems
                          .where(
                            (i) =>
                                !i.timeRemaining.isNegative &&
                                i.daysRemaining <= 7,
                          )
                          .length;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Icon(
                            Icons.person_outline,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        title: Text(
                          ownerName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Expired: $expiredCount • Expiring ≤7d: $soonCount',
                          style: TextStyle(
                            fontSize: 12,
                            color: expiredCount > 0
                                ? Colors.red.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        trailing: Chip(
                          label: Text(
                            '${ownerItems.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedOwner =
                                _ownerFilterOptions.contains(ownerName)
                                    ? ownerName
                                    : 'All';
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Mở màn hình Thêm/Sửa và tự động đồng bộ: SQLite + Thông báo + Lịch + Log
  Future<void> _openAddEditScreen({HouseholdItem? existingItem}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditScreen(existingItem: existingItem),
      ),
    );

    if (result == null) return;

    if (result == 'delete' && existingItem?.id != null) {
      await DatabaseService.instance.deleteItem(existingItem!.id!);
      await NotifyService.instance.cancelItemAlerts(existingItem.id!);
      await CalendarService.instance.deleteItemCalendarEvents(existingItem);
      await LogService.instance.addLog(
        'DELETE',
        'Deleted "${existingItem.name}".',
      );
    } else if (result is HouseholdItem) {
      if (existingItem == null) {
        // 1. Lưu mới vào SQLite để lấy ID
        final newId = await DatabaseService.instance.insertItem(result);
        var savedItem = result.copyWith(id: newId);

        // 2. Tự động đồng bộ các mốc được tick sang Lịch điện thoại & lưu lại eventId
        final syncedAlerts = await CalendarService.instance
            .syncItemCalendarEvents(savedItem);
        savedItem = savedItem.copyWith(alerts: syncedAlerts);
        await DatabaseService.instance.updateItem(savedItem);

        // 3. Đặt lịch thông báo offline + ghi Log
        await NotifyService.instance.scheduleItemAlerts(savedItem);
        await LogService.instance.addLog(
          'ADD',
          'Added "${savedItem.name}" (${savedItem.category}).',
        );
      } else {
        // 1. Đồng bộ lại sự kiện Lịch (tự xóa sự kiện cũ & tạo sự kiện mới)
        final syncedAlerts = await CalendarService.instance
            .syncItemCalendarEvents(
              result,
              previousAlerts: existingItem.alerts,
            );
        final updatedItem = result.copyWith(alerts: syncedAlerts);

        // 2. Cập nhật SQLite + đặt lại thông báo + ghi Log
        await DatabaseService.instance.updateItem(updatedItem);
        await NotifyService.instance.scheduleItemAlerts(updatedItem);
        await LogService.instance.addLog(
          'UPDATE',
          'Updated "${updatedItem.name}".',
        );
      }
    }

    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _filteredItems;
    final ownerOptions = _ownerFilterOptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MinExpiryTracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // MỚI: Nút Biểu đồ mở Thống kê Chủ sở hữu
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Owner Statistics',
            onPressed: _showOwnerStatsSheet,
          ),
          // ĐỔI CHỨC NĂNG: Icon chiếc chuông giờ mở màn hình Xem Log ứng dụng
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'App Logs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              await _loadItems();
            },
          ),
        ],
      ),

      // Bọc SafeArea để danh sách không bao giờ tràn xuống thanh điều hướng dưới
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. THANH LỌC DANH MỤC ---
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                    },
                  );
                },
              ),
            ),

            // --- 2. MỚI: THANH LỌC THEO CHỦ SỞ HỮU (Chỉ hiện khi có dữ liệu chủ sở hữu) ---
            if (ownerOptions.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: ownerOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final owner = ownerOptions[index];
                    return FilterChip(
                      avatar: owner == 'All'
                          ? null
                          : const Icon(Icons.person_outline, size: 16),
                      label: Text(owner == 'All' ? 'All Owners' : owner),
                      selected: _selectedOwner == owner,
                      onSelected: (_) {
                        setState(() => _selectedOwner = owner);
                      },
                    );
                  },
                ),
              ),

            // --- 3. DANH SÁCH VẬT PHẨM ---
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
                                  : 'No items match the current filters.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          // Padding đáy 96px giúp thẻ cuối không bị nút "+ Add Item" che mất
                          padding: const EdgeInsets.only(top: 4, bottom: 96),
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
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditScreen(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}