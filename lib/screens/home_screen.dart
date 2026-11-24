import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import '../services/item_repository.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Giữ khóa nội bộ bằng hằng số chuẩn để đổi ngôn ngữ không làm lệch trạng thái lọc
  String _selectedCategory = AppConstants.filterAll;
  String _selectedOwner = AppConstants.filterAll;
  String _selectedLocation = AppConstants.filterAll;

  List<HouseholdItem> _items = [];
  // MỚI: Lưu sẵn danh sách bộ lọc thay vì tính lại trên mỗi lần gõ phím tìm kiếm
  List<String> _ownerFilterOptions = const [AppConstants.filterAll];
  List<String> _locationFilterOptions = const [AppConstants.filterAll];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _buildOwnerFilterOptions(List<HouseholdItem> items) {
    final owners = items
        .map((e) => e.owner?.trim() ?? '')
        .where((o) => o.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final hasUnassigned = items.any(
      (e) => e.owner == null || e.owner!.trim().isEmpty,
    );

    return [
      AppConstants.filterAll,
      ...owners,
      if (hasUnassigned && owners.isNotEmpty) AppConstants.ownerUnassigned,
    ];
  }

  List<String> _buildLocationFilterOptions(List<HouseholdItem> items) {
    final locations = items
        .map((e) => e.location?.trim() ?? '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final hasUnassigned = items.any(
      (e) => e.location == null || e.location!.trim().isEmpty,
    );

    return [
      AppConstants.filterAll,
      ...locations,
      if (hasUnassigned && locations.isNotEmpty) AppConstants.locationNone,
    ];
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != AppConstants.filterAll ||
      _selectedOwner != AppConstants.filterAll ||
      _selectedLocation != AppConstants.filterAll;

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = AppConstants.filterAll;
      _selectedOwner = AppConstants.filterAll;
      _selectedLocation = AppConstants.filterAll;
    });
  }

  Future<void> _loadItems() async {
    try {
      final items = await ItemRepository.instance.getAllItems();
      if (!mounted) return;

      // Chỉ tính lại bộ lọc đúng 1 lần khi dữ liệu từ SQLite thay đổi
      final ownerOptions = _buildOwnerFilterOptions(items);
      final locationOptions = _buildLocationFilterOptions(items);

      setState(() {
        _items = items;
        _ownerFilterOptions = ownerOptions;
        _locationFilterOptions = locationOptions;
        _isLoading = false;
        if (_selectedOwner != AppConstants.filterAll &&
            !_ownerFilterOptions.contains(_selectedOwner)) {
          _selectedOwner = AppConstants.filterAll;
        }
        if (_selectedLocation != AppConstants.filterAll &&
            !_locationFilterOptions.contains(_selectedLocation)) {
          _selectedLocation = AppConstants.filterAll;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<HouseholdItem> get _filteredItems {
    final l10n = AppLocalizations.of(context)!;
    final keyword = _searchQuery.trim().toLowerCase();

    final filtered = _items.where((item) {
      final matchesCategory = _selectedCategory == AppConstants.filterAll ||
          item.category == _selectedCategory;

      final ownerName = item.owner?.trim() ?? '';
      final bool matchesOwner;
      if (_selectedOwner == AppConstants.filterAll) {
        matchesOwner = true;
      } else if (_selectedOwner == AppConstants.ownerUnassigned) {
        matchesOwner = ownerName.isEmpty;
      } else {
        matchesOwner = ownerName == _selectedOwner;
      }

      final locationName = item.location?.trim() ?? '';
      final bool matchesLocation;
      if (_selectedLocation == AppConstants.filterAll) {
        matchesLocation = true;
      } else if (_selectedLocation == AppConstants.locationNone) {
        matchesLocation = locationName.isEmpty;
      } else {
        matchesLocation = locationName == _selectedLocation;
      }

      final bool matchesSearch;
      if (keyword.isEmpty) {
        matchesSearch = true;
      } else {
        final searchableText = [
          item.name,
          item.category,
          localizeCategory(l10n, item.category),
          item.owner ?? '',
          if (item.owner != null && item.owner!.isNotEmpty)
            localizeOwner(l10n, item.owner!),
          item.location ?? '',
          if (item.location != null && item.location!.isNotEmpty)
            localizeLocation(l10n, item.location!),
          item.notes ?? '',
        ].join(' ').toLowerCase();
        matchesSearch = searchableText.contains(keyword);
      }

      return matchesCategory && matchesOwner && matchesLocation && matchesSearch;
    }).toList();

    // So sánh trực tiếp mốc ngày hết hạn thay vì gọi DateTime.now() nhiều lần qua timeRemaining
    filtered.sort(
      (a, b) => a.effectiveDeadline.compareTo(b.effectiveDeadline),
    );
    return filtered;
  }

  // --- MỚI: BẢNG TRƯỢT DÙNG CHUNG CHO CẢ 3 BỘ LỌC (DANH MỤC / CHỦ SỞ HỮU / VỊ TRÍ) ---
  void _showFilterPickerSheet({
    required String title,
    required List<String> options,
    required String selectedValue,
    required String Function(String value) labelBuilder,
    required ValueChanged<String> onSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option == selectedValue;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      title: Text(
                        labelBuilder(option),
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: colorScheme.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(option);
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

  // --- MỚI: TẠO CHIP THẢ XUỐNG KIỂU GOOGLE DRIVE ---
  Widget _buildDropdownFilterChip({
    required IconData icon,
    required String defaultLabel,
    required String selectedValue,
    required String Function(String value) labelBuilder,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = selectedValue != AppConstants.filterAll;
    final String displayLabel =
        isSelected ? labelBuilder(selectedValue) : defaultLabel;

    return InputChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant,
      ),
      label: isSelected
          ? Text(
              displayLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayLabel),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
      selected: isSelected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      // Khi đang bật lọc -> hiện nút × để xóa nhanh trong 1 chạm
      onDeleted: isSelected ? onClear : null,
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }

  void _showOwnerStatsSheet() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final Map<String, List<HouseholdItem>> grouped = {};
    for (final item in _items) {
      final key = (item.owner == null || item.owner!.trim().isEmpty)
          ? AppConstants.ownerUnassigned
          : item.owner!.trim();
      grouped.putIfAbsent(key, () => []).add(item);
    }

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
                  Text(
                    l10n.ownerStatistics,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    l10n.totalItems(_items.length),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tapOwnerToFilter,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (sortedEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text(l10n.noItemsToSummarize)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedEntries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = sortedEntries[index];
                      final ownerKey = entry.key;
                      final displayOwner = localizeOwner(l10n, ownerKey);
                      final ownerItems = entry.value;

                      final expiredCount =
                          ownerItems.where((i) => i.isExpired).length;
                      final soonCount =
                          ownerItems.where((i) => i.isExpiringSoon()).length;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person_outline,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          displayOwner,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          l10n.ownerStatsSubtitle(expiredCount, soonCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: expiredCount > 0
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
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
                                _ownerFilterOptions.contains(ownerKey)
                                    ? ownerKey
                                    : AppConstants.filterAll;
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

  void _showCalendarError(String errorKey, String itemName) {
    final l10n = AppLocalizations.of(context)!;
    final errorMessage = localizeLogMessage(
      l10n,
      encodeLogMessage(errorKey, {'name': itemName}),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l10n.appLogs,
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LogScreen()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddEditScreen({HouseholdItem? existingItem}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditScreen(existingItem: existingItem),
      ),
    );

    if (result == null) return;

    if (result == 'delete' && existingItem != null) {
      await ItemRepository.instance.deleteItem(existingItem);
    } else if (result is HouseholdItem) {
      final ItemOperationResult opResult;
      if (existingItem == null) {
        opResult = await ItemRepository.instance.addItem(result);
      } else {
        opResult = await ItemRepository.instance.updateItem(
          result,
          previous: existingItem,
        );
      }

      if (opResult.hasCalendarError && mounted) {
        _showCalendarError(opResult.calendarErrorKey!, opResult.item.name);
      }
    }

    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final displayItems = _filteredItems;
    final ownerOptions = _ownerFilterOptions;
    final locationOptions = _locationFilterOptions;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: l10n.ownerStatistics,
            onPressed: _showOwnerStatsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: l10n.appLogs,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
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
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. THANH TÌM KIẾM NHANH ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: l10n.clearSearch,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // --- 2. MỘT HÀNG DUY NHẤT GỒM 3 CHIP LỌC THẢ XUỐNG ---
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  // Chip 1: Danh mục
                  _buildDropdownFilterChip(
                    icon: Icons.category_outlined,
                    defaultLabel: l10n.filterCategory,
                    selectedValue: _selectedCategory,
                    labelBuilder: (cat) => localizeCategory(l10n, cat),
                    onTap: () => _showFilterPickerSheet(
                      title: l10n.filterCategory,
                      options: AppConstants.filterCategories,
                      selectedValue: _selectedCategory,
                      labelBuilder: (cat) => localizeCategory(l10n, cat),
                      onSelected: (val) =>
                          setState(() => _selectedCategory = val),
                    ),
                    onClear: () => setState(
                      () => _selectedCategory = AppConstants.filterAll,
                    ),
                  ),

                  // Chip 2: Chủ sở hữu (chỉ hiện khi đã có dữ liệu chủ sở hữu)
                  if (ownerOptions.length > 1) ...[
                    const SizedBox(width: 8),
                    _buildDropdownFilterChip(
                      icon: Icons.person_outline,
                      defaultLabel: l10n.filterOwner,
                      selectedValue: _selectedOwner,
                      labelBuilder: (owner) => localizeOwner(l10n, owner),
                      onTap: () => _showFilterPickerSheet(
                        title: l10n.filterOwner,
                        options: ownerOptions,
                        selectedValue: _selectedOwner,
                        labelBuilder: (owner) => localizeOwner(l10n, owner),
                        onSelected: (val) =>
                            setState(() => _selectedOwner = val),
                      ),
                      onClear: () => setState(
                        () => _selectedOwner = AppConstants.filterAll,
                      ),
                    ),
                  ],

                  // Chip 3: Vị trí (chỉ hiện khi đã có dữ liệu vị trí)
                  if (locationOptions.length > 1) ...[
                    const SizedBox(width: 8),
                    _buildDropdownFilterChip(
                      icon: Icons.location_on_outlined,
                      defaultLabel: l10n.filterLocation,
                      selectedValue: _selectedLocation,
                      labelBuilder: (loc) => localizeLocation(l10n, loc),
                      onTap: () => _showFilterPickerSheet(
                        title: l10n.filterLocation,
                        options: locationOptions,
                        selectedValue: _selectedLocation,
                        labelBuilder: (loc) => localizeLocation(l10n, loc),
                        onSelected: (val) =>
                            setState(() => _selectedLocation = val),
                      ),
                      onClear: () => setState(
                        () => _selectedLocation = AppConstants.filterAll,
                      ),
                    ),
                  ],
                ],
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _items.isEmpty
                                      ? l10n.noItemsYet
                                      : l10n.noItemsMatchFilters,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 15,
                                  ),
                                ),
                                if (_items.isNotEmpty && _hasActiveFilters) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _resetAllFilters,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: Text(l10n.clearAllFilters),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.only(top: 4, bottom: 96),
                          itemCount: displayItems.length,
                          itemBuilder: (context, index) {
                            final item = displayItems[index];
                            return ItemCard(
                              item: item,
                              onTap: () =>
                                  _openAddEditScreen(existingItem: item),
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
        label: Text(l10n.addItem),
      ),
    );
  }
}