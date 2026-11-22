import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';

class AddEditScreen extends StatefulWidget {
  final HouseholdItem? existingItem;

  const AddEditScreen({super.key, this.existingItem});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _paoValueController; // Đổi tên từ paoMonths -> paoValue
  late final TextEditingController _quantityController;
  late final TextEditingController _ownerController;

  final List<String> _categories = ['Medicine', 'Cosmetics', 'Food', 'Other'];
  late String _selectedCategory;
  DateTime? _expiryDate;
  DateTime? _openedDate;
  late String _paoUnit; // MỚI: Lưu đơn vị PAO ('months', 'days', 'hours')
  late List<int> _alertDays;

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
    _ownerController = TextEditingController(text: item?.owner ?? '');

    _selectedCategory = item?.category ?? 'Medicine';
    _expiryDate = item?.expiryDate;
    _openedDate = item?.openedDate;
    _paoUnit = item?.paoUnit ?? 'months';

    _alertDays = item != null ? List<int>.from(item.alertDays) : [30, 7];
    _alertDays.sort((a, b) => b.compareTo(a));

    _imageBase64 = item?.imageBase64;
    _imageBytes = item?.imageBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paoValueController.dispose();
    _quantityController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  // --- 1. CHỌN HOẶC CHỤP ẢNH VÀ TỰ ĐỘNG NÉN SANG BASE64 ---
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

  // --- 2. MỞ LỊCH CHỌN NGÀY ---
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
          // Giữ lại giờ/phút cũ (hoặc lấy giờ hiện tại nếu mới chọn lần đầu)
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

  // --- 2B. MỚI: MỞ ĐỒNG HỒ CHỌN GIỜ MỞ NẮP (Dùng khi PAO tính theo Giờ) ---
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

  // --- 3. HỘP THOẠI THÊM MỐC CẢNH BÁO RIÊNG ---
  Future<void> _showAddAlertDialog() async {
    final controller = TextEditingController();

    final int? newDays = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Alert Milestone'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Days before expiry',
            hintText: 'e.g., 14',
            suffixText: 'days',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newDays != null && !_alertDays.contains(newDays)) {
      setState(() {
        _alertDays.add(newDays);
        _alertDays.sort((a, b) => b.compareTo(a));
      });
    }
  }

  // --- 4. LƯU VẬT PHẨM VÀ TRẢ KẾT QUẢ VỀ MÀN HÌNH CHÍNH ---
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
      owner: _ownerController.text.trim().isEmpty
          ? null
          : _ownerController.text.trim(),
      imageBase64: _imageBase64,
      alertDays: _alertDays,
    );

    Navigator.pop(context, savedItem);
  }

  // --- 5. XÁC NHẬN XÓA VẬT PHẨM ---
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 32,
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
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
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
              const SizedBox(height: 16),

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
              const SizedBox(height: 24),

              // === KHU VỰC 3: HẠN SỬ DỤNG SAU MỞ NẮP - PAO (ĐÃ NÂNG CẤP) ===
              const Text(
                'Period After Opening (Optional)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Track by months (cosmetics), days (milk), or hours (prepared food).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),

              // Hàng 1: Nhập số PAO + Chọn đơn vị (Months / Days / Hours)
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
              const SizedBox(height: 12),

              // Hàng 2: Chọn Ngày mở nắp + Tự hiện nút Chọn Giờ nếu đơn vị là Hours
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
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
                  // Chỉ hiện nút chọn giờ khi người dùng chọn đơn vị là 'hours'
                  if (_paoUnit == 'hours') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
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
              const SizedBox(height: 24),

              // === KHU VỰC 4: SỐ LƯỢNG & NGƯỜI SỬ DỤNG ===
              const Text(
                'Additional Details (Optional)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
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
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _ownerController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Owner / User',
                        hintText: 'e.g., Me, Mom, Family',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === KHU VỰC 5: MỐC CẢNH BÁO RIÊNG ===
              const Text(
                'Custom Alert Milestones',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Notify me before this item expires:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ..._alertDays.map((days) {
                    return InputChip(
                      label: Text('$days days before'),
                      onDeleted: () {
                        setState(() => _alertDays.remove(days));
                      },
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Add alert'),
                    onPressed: _showAddAlertDialog,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // === NÚT LƯU (SAVE) ===
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _saveItem,
                  icon: const Icon(Icons.check),
                  label: Text(
                    _isEditing ? 'Save Changes' : 'Add Item',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}