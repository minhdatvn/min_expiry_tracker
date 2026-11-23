import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Giữ khóa nội bộ bằng tiếng Anh để đổi ngôn ngữ không làm hỏng trạng thái lọc
  String _selectedCategory = 'All';
  String _selectedOwner = 'All';
  String _selectedLocation = 'All';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  List<String> get _locationFilterOptions {
    final locations = _items
        .map((e) => e.location?.trim() ?? '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final hasUnassigned = _items.any(
      (e) => e.location == null || e.location!.trim().isEmpty,
    );

    return [
      'All',
      ...locations,
      if (hasUnassigned && locations.isNotEmpty) 'No Location',
    ];
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != 'All' ||
      _selectedOwner != 'All' ||
      _selectedLocation != 'All';

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = 'All';
      _selectedOwner = 'All';
      _selectedLocation = 'All';
    });
  }

  Future<void> _loadItems() async {
    final items = await DatabaseService.instance.getAllItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
      if (_selectedOwner != 'All' &&
          !_ownerFilterOptions.contains(_selectedOwner)) {
        _selectedOwner = 'All';
      }
      if (_selectedLocation != 'All' &&
          !_locationFilterOptions.contains(_selectedLocation)) {
        _selectedLocation = 'All';
      }
    });
  }

  List<HouseholdItem> get _filteredItems {
    final l10n = AppLocalizations.of(context)!;
    final keyword = _searchQuery.trim().toLowerCase();

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

      final locationName = item.location?.trim() ?? '';
      final bool matchesLocation;
      if (_selectedLocation == 'All') {
        matchesLocation = true;
      } else if (_selectedLocation == 'No Location') {
        matchesLocation = locationName.isEmpty;
      } else {
        matchesLocation = locationName == _selectedLocation;
      }

      final bool matchesSearch;
      if (keyword.isEmpty) {
        matchesSearch = true;
      } else {
        // Cho phép tìm cả tên danh mục tiếng Anh lẫn tiếng Việt (VD: gõ "Thuốc" hoặc "Medicine")
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
        matchesSearch = searchableText.contains(keyword); // <-- BỔ SUNG DÒNG NÀY
      }

      return matchesCategory && matchesOwner && matchesLocation && matchesSearch;
    }).toList();

    filtered.sort((a, b) => a.timeRemaining.compareTo(b.timeRemaining));
    return filtered;
  }

  void _showOwnerStatsSheet() {
    final l10n = AppLocalizations.of(context)!;
    final Map<String, List<HouseholdItem>> grouped = {};
    for (final item in _items) {
      final key = (item.owner == null || item.owner!.trim().isEmpty)
          ? 'Unassigned'
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
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tapOwnerToFilter,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                          displayOwner,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          l10n.ownerStatsSubtitle(expiredCount, soonCount),
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
                                _ownerFilterOptions.contains(ownerKey)
                                    ? ownerKey
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
        encodeLogMessage('logItemDeleted', {'name': existingItem.name}),
      );
    } else if (result is HouseholdItem) {
      if (existingItem == null) {
        final newId = await DatabaseService.instance.insertItem(result);
        var savedItem = result.copyWith(id: newId);

        final syncedAlerts = await CalendarService.instance
            .syncItemCalendarEvents(savedItem);
        savedItem = savedItem.copyWith(alerts: syncedAlerts);
        await DatabaseService.instance.updateItem(savedItem);

        await NotifyService.instance.scheduleItemAlerts(savedItem);
        await LogService.instance.addLog(
          'ADD',
          encodeLogMessage('logItemAdded', {
            'name': savedItem.name,
            'category': savedItem.category,
          }),
        );
      } else {
        final syncedAlerts = await CalendarService.instance
            .syncItemCalendarEvents(
              result,
              previousAlerts: existingItem.alerts,
            );
        final updatedItem = result.copyWith(alerts: syncedAlerts);

        await DatabaseService.instance.updateItem(updatedItem);
        await NotifyService.instance.scheduleItemAlerts(updatedItem);
        await LogService.instance.addLog(
          'UPDATE',
          encodeLogMessage('logItemUpdated', {'name': updatedItem.name}),
        );
      }
    }

    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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

            // --- 2. THANH LỌC DANH MỤC ---
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return ChoiceChip(
                    label: Text(localizeCategory(l10n, category)),
                    selected: _selectedCategory == category,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                    },
                  );
                },
              ),
            ),

            // --- 3. THANH LỌC CHỦ SỞ HỮU ---
            if (ownerOptions.length > 1)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  itemCount: ownerOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final owner = ownerOptions[index];
                    final label = localizeOwner(l10n, owner);

                    return FilterChip(
                      avatar: owner == 'All'
                          ? null
                          : const Icon(Icons.person_outline, size: 16),
                      label: Text(label),
                      selected: _selectedOwner == owner,
                      onSelected: (_) {
                        setState(() => _selectedOwner = owner);
                      },
                    );
                  },
                ),
              ),

            // --- 4. THANH LỌC VỊ TRÍ ---
            if (locationOptions.length > 1)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  itemCount: locationOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final location = locationOptions[index];
                    final label = localizeLocation(l10n, location);

                    return FilterChip(
                      avatar: location == 'All'
                          ? null
                          : const Icon(Icons.location_on_outlined, size: 16),
                      label: Text(label),
                      selected: _selectedLocation == location,
                      onSelected: (_) {
                        setState(() => _selectedLocation = location);
                      },
                    );
                  },
                ),
              ),

            // --- 5. DANH SÁCH VẬT PHẨM ---
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
                                    color: Colors.grey.shade600,
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
        label: Text(l10n.addItem),
      ),
    );
  }
}