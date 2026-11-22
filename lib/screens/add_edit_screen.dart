import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';

class AddEditScreen extends StatefulWidget {
  // Nếu existingItem == null -> Chế độ THÊM MỚI
  // Nếu existingItem != null -> Chế độ CHỈNH SỬA vật phẩm đó
  final HouseholdItem? existingItem;

  const AddEditScreen({super.key, this.existingItem});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  // Chìa khóa giúp kiểm tra hợp lệ (validate) toàn bộ các ô nhập liệu cùng lúc
  final _formKey = GlobalKey<FormState>();

  // Các "bộ điều khiển" (Controller) để đọc và gán chữ trong ô nhập liệu
  late final TextEditingController _nameController;
  late final TextEditingController _paoMonthsController;
  late final TextEditingController _quantityController;
  late final TextEditingController _ownerController;

  // Các biến lưu trạng thái đang chọn trên màn hình
  final List<String> _categories = ['Medicine', 'Cosmetics', 'Food', 'Other'];
  late String _selectedCategory;
  DateTime? _expiryDate;
  DateTime? _openedDate;
  late List<int> _alertDays;

  // Lưu cả chuỗi Base64 (để lưu dữ liệu) và bytes (để vẽ ảnh mượt mà)
  String? _imageBase64;
  Uint8List? _imageBytes;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    // Nếu đang sửa thì điền sẵn dữ liệu cũ, nếu thêm mới thì để giá trị mặc định
    _nameController = TextEditingController(text: item?.name ?? '');
    _paoMonthsController = TextEditingController(
      text: item?.paoMonths?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: item?.quantity?.toString() ?? '',
    );
    _ownerController = TextEditingController(text: item?.owner ?? '');

    _selectedCategory = item?.category ?? 'Medicine';
    _expiryDate = item?.expiryDate;
    _openedDate = item?.openedDate;

    // Tạo bản sao danh sách alertDays để tránh làm hỏng dữ liệu gốc nếu bấm hủy
    _alertDays = item != null ? List<int>.from(item.alertDays) : [30, 7];
    _alertDays.sort((a, b) => b.compareTo(a)); // Sắp xếp từ lớn đến nhỏ (VD: 30, 7)

    _imageBase64 = item?.imageBase64;
    _imageBytes = item?.imageBytes;
  }

  @override
  void dispose() {
    // Dọn dẹp các Controller khỏi bộ nhớ RAM khi đóng màn hình
    _nameController.dispose();
    _paoMonthsController.dispose();
    _quantityController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  // --- 1. CHỌN HOẶC CHỤP ẢNH VÀ TỰ ĐỘNG NÉN SANG BASE64 ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();

    // Thu nhỏ ảnh về tối đa 600x600px và nén chất lượng 70% -> Ảnh chỉ còn khoảng 25-40KB
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );

    if (pickedFile == null) return; // Người dùng bấm hủy không chọn ảnh

    // Đọc dữ liệu ảnh đã nén và mã hóa thành chuỗi Base64
    final Uint8List bytes = await pickedFile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageBase64 = base64Encode(bytes);
    });
  }

  // Hiện bảng trượt từ đáy màn hình để chọn Camera hay Thư viện ảnh
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
    final initial = isExpiryDate
        ? (_expiryDate ?? DateTime.now().add(const Duration(days: 30)))
        : (_openedDate ?? DateTime.now());

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
          _openedDate = picked;
        }
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
        _alertDays.sort((a, b) => b.compareTo(a)); // Giữ thứ tự từ xa đến gần
      });
    }
  }

  // --- 4. LƯU VẬT PHẨM VÀ TRẢ KẾT QUẢ VỀ MÀN HÌNH CHÍNH ---
  void _saveItem() {
    // Kiểm tra xem các ô bắt buộc (như Name) đã nhập chưa
    if (!_formKey.currentState!.validate()) return;

    // Kiểm tra bắt buộc phải chọn ngày hết hạn
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date.')),
      );
      return;
    }

    final savedItem = HouseholdItem(
      // Nếu thêm mới thì id là null để SQLite tự cấp ID chuẩn (1, 2, 3...)
      id: widget.existingItem?.id,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      expiryDate: _expiryDate!,
      openedDate: _openedDate,
      paoMonths: int.tryParse(_paoMonthsController.text.trim()),
      quantity: int.tryParse(_quantityController.text.trim()),
      owner: _ownerController.text.trim().isEmpty
          ? null
          : _ownerController.text.trim(),
      imageBase64: _imageBase64,
      alertDays: _alertDays,
    );

    // Đóng màn hình này và gửi vật phẩm vừa lưu ngược về HomeScreen
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

    // Nếu người dùng đồng ý xóa -> đóng màn hình và gửi tín hiệu 'delete' về HomeScreen
    if (confirm == true && mounted) {
      Navigator.pop(context, 'delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add New Item'),
        actions: [
          // Chỉ hiện nút Xóa khi đang mở một vật phẩm đã có sẵn
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),

      // SingleChildScrollView giúp cuộn màn hình mượt khi bàn phím Android bật lên
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === KHU VỰC 1: ẢNH CHỤP SẢN PHẨM (TÙY CHỌN) ===
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
                  hintText: 'e.g., Vitamin C Serum, Panadol',
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

              // Danh mục sản phẩm (Bắt buộc)
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

              // Chọn Ngày hết hạn trên bao bì (Bắt buộc)
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

              // === KHU VỰC 3: HẠN SỬ DỤNG SAU MỞ NẮP - PAO (TÙY CHỌN) ===
              const Text(
                'Period After Opening (Optional)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Useful for cosmetics & eye drops. Fill both fields to track PAO.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  // Chọn ngày mở nắp
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
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
                  if (_openedDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear opened date',
                      onPressed: () => setState(() => _openedDate = null),
                    ),
                  const SizedBox(width: 10),

                  // Nhập số tháng dùng sau khi mở
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _paoMonthsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PAO (Months)',
                        hintText: '6',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === KHU VỰC 4: SỐ LƯỢNG & NGƯỜI SỬ DỤNG (TÙY CHỌN) ===
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

              // === KHU VỰC 5: MỐC CẢNH BÁO RIÊNG CHO TỪNG MÓN ===
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
