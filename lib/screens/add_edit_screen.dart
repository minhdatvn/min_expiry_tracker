import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';
import '../services/database_service.dart';

class AddEditScreen extends StatefulWidget {
  final HouseholdItem? existingItem;

  const AddEditScreen({super.key, this.existingItem});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Các bộ điều khiển ô nhập liệu
  late final TextEditingController _nameController;
  late final TextEditingController _paoValueController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;      // MỚI: Ghi chú
  late final TextEditingController _alertValueController; // MỚI: Khung nhập số thông báo

  // Danh mục & ngày tháng
  final List<String> _categories = ['Medicine', 'Cosmetics', 'Food', 'Other'];
  late String _selectedCategory;
  DateTime? _expiryDate;
  DateTime? _openedDate;
  late String _paoUnit;

  // MỚI: Chủ sở hữu & Vị trí (chọn nhanh bằng danh sách giá trị)
  String? _selectedOwner;
  List<String> _availableOwners = ['Me', 'Family'];

  String? _selectedLocation;
  List<String> _availableLocations = ['Fridge', 'Medicine Box', 'Bathroom'];

  // MỚI: Danh sách mốc thông báo thông minh + đơn vị đang chọn để thêm
  late List<AlertMilestone> _alerts;
  String _newAlertUnit = 'days';

  // Ảnh chụp sản phẩm
  String? _imageBase64;
  Uint8List? _imageBytes;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _paoValueController = TextEditingController(
      text: item?.paoValue?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: item?.quantity?.toString() ?? '',
    );
    _notesController = TextEditingController(text: item?.notes ?? '');
    _alertValueController = TextEditingController();

    _selectedCategory = item?.category ?? 'Medicine';
    _expiryDate = item?.expiryDate;
    _openedDate = item?.openedDate;
    _paoUnit = item?.paoUnit ?? 'months';

    _selectedOwner = item?.owner;
    _selectedLocation = item?.location;

    _alerts = item != null
        ? List<AlertMilestone>.from(item.alerts)
        : [
            const AlertMilestone(value: 30, unit: 'days'),
            const AlertMilestone(value: 7, unit: 'days'),
          ];
    _alerts.sort((a, b) => b.totalHours.compareTo(a.totalHours));

    _imageBase64 = item?.imageBase64;
    _imageBytes = item?.imageBytes;

    // Tải các giá trị Owner & Location đã từng dùng từ SQLite để gợi ý chọn nhanh
    _loadSavedSuggestions();
  }

  Future<void> _loadSavedSuggestions() async {
    final savedOwners = await DatabaseService.instance.getDistinctOwners();
    final savedLocations = await DatabaseService.instance.getDistinctLocations();

    if (!mounted) return;
    setState(() {
      // Dùng Set để tự động lọc trùng lặp, giữ lại cả gợi ý mặc định lẫn dữ liệu của bạn
      final ownerSet = <String>{
        ..._availableOwners,
        ...savedOwners,
        if (_selectedOwner != null && _selectedOwner!.isNotEmpty)
          _selectedOwner!,
      };
      _availableOwners = ownerSet.toList();

      final locationSet = <String>{
        ..._availableLocations,
        ...savedLocations,
        if (_selectedLocation != null && _selectedLocation!.isNotEmpty)
          _selectedLocation!,
      };
      _availableLocations = locationSet.toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paoValueController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _alertValueController.dispose();
    super.dispose();
  }

  // --- 1. CHỌN HOẶC CHỤP ẢNH VÀ NÉN BASE64 ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    final Uint8List bytes = await pickedFile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageBase64 = base64Encode(bytes);
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imageBytes != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageBytes = null;
                    _imageBase64 = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- 2. CHỌN NGÀY & GIỜ ---
  Future<void> _selectDate({required bool isExpiryDate}) async {
    final now = DateTime.now();
    final initial = isExpiryDate
        ? (_expiryDate ?? now.add(const Duration(days: 30)))
        : (_openedDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isExpiryDate) {
          _expiryDate = picked;
        } else {
          final hour = _openedDate?.hour ?? now.hour;
          final minute = _openedDate?.minute ?? now.minute;
          _openedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            hour,
            minute,
          );
        }
      });
    }
  }

  Future<void> _selectOpenedTime() async {
    final baseDate = _openedDate ?? DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baseDate),
    );

    if (pickedTime != null) {
      setState(() {
        _openedDate = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  // --- 3. MỚI: HỘP THOẠI THÊM GIÁ TRỊ MỚI CHO CHỦ SỞ HỮU HOẶC VỊ TRÍ ---
  Future<void> _showAddTagDialog({
    required String title,
    required String hintText,
    required bool isOwner,
  }) async {
    final controller = TextEditingController();

    final String? newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context, text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newValue != null && mounted) {
      setState(() {
        if (isOwner) {
          if (!_availableOwners.contains(newValue)) {
            _availableOwners.add(newValue);
          }
          _selectedOwner = newValue;
        } else {
          if (!_availableLocations.contains(newValue)) {
            _availableLocations.add(newValue);
          }
          _selectedLocation = newValue;
        }
      });
    }
  }

  // --- 4. MỚI: THÊM MỐC CẢNH BÁO TỪ 2 KHUNG (SỐ + ĐƠN VỊ) + NÚT CỘNG ---
  void _addAlertMilestone() {
    final value = int.tryParse(_alertValueController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive number.')),
      );
      return;
    }

    final alreadyExists = _alerts.any(
      (a) => a.value == value && a.unit == _newAlertUnit,
    );
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This alert milestone already exists.')),
      );
      return;
    }

    setState(() {
      _alerts.add(AlertMilestone(value: value, unit: _newAlertUnit));
      _alerts.sort((a, b) => b.totalHours.compareTo(a.totalHours));
      _alertValueController.clear();
    });
  }

  // --- 5. LƯU VẬT PHẨM ---
  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;

    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date.')),
      );
      return;
    }

    final savedItem = HouseholdItem(
      id: widget.existingItem?.id,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      expiryDate: _expiryDate!,
      openedDate: _openedDate,
      paoValue: int.tryParse(_paoValueController.text.trim()),
      paoUnit: _paoUnit,
      quantity: int.tryParse(_quantityController.text.trim()),
      owner: _selectedOwner,
      location: _selectedLocation,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      imageBase64: _imageBase64,
      alerts: _alerts,
    );

    Navigator.pop(context, savedItem);
  }

  // --- 6. XÁC NHẬN XÓA ---
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Remove "${widget.existingItem!.name}" from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context, 'delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      // Tự co giãn vùng cuộn khi bàn phím ảo bật lên -> chống sọc vàng đen báo tràn
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add New Item'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),

      // SafeArea bao toàn bộ nội dung để không bị đè vào thanh điều hướng Android
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === KHU VỰC 1: ẢNH CHỤP SẢN PHẨM ===
                Center(
                  child: GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 30,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Add Photo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // === KHU VỰC 2: THÔNG TIN BẮT BUỘC ===
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    hintText: 'e.g., Vitamin C Serum, Fresh Milk',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCategory = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          hintText: '1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade500),
                  ),
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Expiry Date *'),
                  subtitle: Text(
                    _expiryDate != null
                        ? dateFormat.format(_expiryDate!)
                        : 'Tap to select date',
                    style: TextStyle(
                      color: _expiryDate != null
                          ? Colors.black87
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectDate(isExpiryDate: true),
                ),
                const SizedBox(height: 22),

                // === KHU VỰC 3: HẠN SAU MỞ NẮP (PAO) ===
                const Text(
                  'Period After Opening (Optional)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _paoValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'PAO Value',
                          hintText: 'e.g., 6',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _paoUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'months', child: Text('Months')),
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                          DropdownMenuItem(value: 'hours', child: Text('Hours')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _paoUnit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.lock_open_outlined, size: 18),
                        label: Text(
                          _openedDate != null
                              ? dateFormat.format(_openedDate!)
                              : 'Opened Date',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _selectDate(isExpiryDate: false),
                      ),
                    ),
                    if (_paoUnit == 'hours') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text(
                            _openedDate != null
                                ? timeFormat.format(_openedDate!)
                                : 'Time',
                          ),
                          onPressed: _selectOpenedTime,
                        ),
                      ),
                    ],
                    if (_openedDate != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear opened date',
                        onPressed: () => setState(() => _openedDate = null),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // === KHU VỰC 4: CHỦ SỞ HỮU (CHỌN NHANH ĐỂ LỌC & THỐNG KÊ) ===
                const Text(
                  'Owner (Optional)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ..._availableOwners.map((owner) {
                      final isSelected = _selectedOwner == owner;
                      return ChoiceChip(
                        label: Text(owner),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedOwner = selected ? owner : null;
                          });
                        },
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('New Owner'),
                      onPressed: () => _showAddTagDialog(
                        title: 'Add New Owner',
                        hintText: 'e.g., Mom, Dad, Kids',
                        isOwner: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // === KHU VỰC 5: VỊ TRÍ CẤT GIỮ (TÙY CHỌN, CHỌN NHANH) ===
                const Text(
                  'Location (Optional)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ..._availableLocations.map((loc) {
                      final isSelected = _selectedLocation == loc;
                      return ChoiceChip(
                        label: Text(loc),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedLocation = selected ? loc : null;
                          });
                        },
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add_location_alt_outlined, size: 18),
                      label: const Text('New Location'),
                      onPressed: () => _showAddTagDialog(
                        title: 'Add New Location',
                        hintText: 'e.g., Kitchen Shelf, Bedroom',
                        isOwner: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // === KHU VỰC 6: THÔNG BÁO TÙY CHỌN + TICK THÊM VÀO LỊCH ===
                const Text(
                  'Custom Alerts & Device Calendar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter time before expiry and tap + to add. Tick "Calendar" to auto-sync that alert.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),

                // 2 khung (Số + Đơn vị) và nút dấu Cộng (+) nằm gọn 1 hàng
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _alertValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Before',
                          hintText: 'e.g., 3',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _newAlertUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'hours', child: Text('Hours')),
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _newAlertUnit = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addAlertMilestone,
                      icon: const Icon(Icons.add),
                      tooltip: 'Add Alert',
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Danh sách các mốc đã thêm — mỗi mốc có Checkbox Calendar riêng
                if (_alerts.isEmpty)
                  Text(
                    'No alerts set for this item.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  )
                else
                  Column(
                    children: _alerts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final alert = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              alert.unit == 'hours'
                                  ? Icons.schedule
                                  : Icons.notifications_outlined,
                              size: 18,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alert.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            // Ô tick riêng để tự động đồng bộ mốc này vào Lịch điện thoại
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setState(() {
                                  _alerts[index] = alert.copyWith(
                                    addToCalendar: !alert.addToCalendar,
                                  );
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: alert.addToCalendar,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (checked) {
                                      setState(() {
                                        _alerts[index] = alert.copyWith(
                                          addToCalendar: checked ?? false,
                                        );
                                      });
                                    },
                                  ),
                                  const Text(
                                    'Calendar',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Remove alert',
                              onPressed: () {
                                setState(() => _alerts.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 18),

                // === KHU VỰC 7: MỚI - GHI CHÚ TỰ DO NHIỀU DÒNG ===
                const Text(
                  'Notes (Optional)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Storage tips, dosage, where you bought it...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // MỚI: Thanh nút Lưu ghim gọn phía dưới & bọc SafeArea -> CHỐNG TRÀN VIỀN DƯỚI TUYỆT ĐỐI
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _saveItem,
              icon: const Icon(Icons.check),
              label: Text(
                _isEditing ? 'Save Changes' : 'Add Item',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}