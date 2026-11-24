import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import '../services/item_repository.dart';
import '../widgets/alerts_section.dart';
import '../widgets/tag_selector_section.dart';

class AddEditScreen extends StatefulWidget {
  final HouseholdItem? existingItem;

  const AddEditScreen({super.key, this.existingItem});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _paoValueController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;

  late String _selectedCategory;
  DateTime? _expiryDate;
  DateTime? _openedDate;
  late String _paoUnit;

  // Khởi tạo bản sao có thể chỉnh sửa từ danh sách hằng số gốc
  String? _selectedOwner;
  List<String> _availableOwners =
      List<String>.from(AppConstants.defaultOwners);

  String? _selectedLocation;
  List<String> _availableLocations =
      List<String>.from(AppConstants.defaultLocations);

  late List<AlertMilestone> _alerts;

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

    _selectedCategory = item?.category ?? AppConstants.defaultCategories.first;
    _expiryDate = item?.expiryDate;
    _openedDate = item?.openedDate;
    _paoUnit = item?.paoUnit ?? 'months';

    _selectedOwner = item?.owner;
    _selectedLocation = item?.location;

    _alerts = item != null
        ? List<AlertMilestone>.from(item.alerts)
        : List<AlertMilestone>.from(AppConstants.defaultAlerts);
    _alerts.sort((a, b) => b.totalHours.compareTo(a.totalHours));

    _imageBase64 = item?.imageBase64;
    _imageBytes = item?.imageBytes;

    _loadSavedSuggestions();
  }

  Future<void> _loadSavedSuggestions() async {
    final tags = await ItemRepository.instance.getSavedTags();
    final savedOwners = tags.owners;
    final savedLocations = tags.locations;

    if (!mounted) return;
    setState(() {
      _availableOwners = <String>{
        ..._availableOwners,
        ...savedOwners,
        if (_selectedOwner != null && _selectedOwner!.isNotEmpty)
          _selectedOwner!,
      }.toList();

      _availableLocations = <String>{
        ..._availableLocations,
        ...savedLocations,
        if (_selectedLocation != null && _selectedLocation!.isNotEmpty)
          _selectedLocation!,
      }.toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paoValueController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- 1. CHỌN HOẶC CHỤP ẢNH VÀ NÉN BASE64 ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 65,
      );

      if (pickedFile == null || !mounted) return;

      final Uint8List bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageBase64 = base64Encode(bytes);
      });
    } catch (_) {
      // Bỏ qua êm ái nếu thiết bị từ chối quyền Camera/Thư viện
    }
  }

  void _showImageSourceSheet() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imageBytes != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  l10n.removePhoto,
                  style: const TextStyle(color: Colors.red),
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

  // --- 3. HỘP THOẠI THÊM CHỦ SỞ HỮU / VỊ TRÍ ---
  Future<void> _showAddTagDialog({
    required String title,
    required String hintText,
    required bool isOwner,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    String inputText = '';

    final String? newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) => inputText = value,
          onSubmitted: (value) {
            final text = value.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final text = inputText.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context, text);
              }
            },
            child: Text(l10n.add),
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

  // --- 4. LƯU VẬT PHẨM ---
  void _saveItem() {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectExpiryDateError)),
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

  // --- 5. XÁC NHẬN XÓA ---
  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteItemTitle),
        content: Text(l10n.deleteItemConfirm(widget.existingItem!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editItem : l10n.addNewItem),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: l10n.delete,
              onPressed: _confirmDelete,
            ),
        ],
      ),
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
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
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
                                  l10n.addPhoto,
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
                  decoration: InputDecoration(
                    labelText: l10n.itemNameLabel,
                    hintText: l10n.itemNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.itemNameError;
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
                        decoration: InputDecoration(
                          labelText: l10n.categoryLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: AppConstants.defaultCategories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(localizeCategory(l10n, cat)),
                          );
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
                        decoration: InputDecoration(
                          labelText: l10n.quantityLabel,
                          hintText: '1',
                          border: const OutlineInputBorder(),
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
                  title: Text(l10n.expiryDateLabel),
                  subtitle: Text(
                    _expiryDate != null
                        ? formatDateByLocale(context, _expiryDate!)
                        : l10n.tapToSelectDate,
                    style: TextStyle(
                      color: _expiryDate != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectDate(isExpiryDate: true),
                ),
                const SizedBox(height: 22),

                // === KHU VỰC 3: HẠN SAU MỞ NẮP (PAO) ===
                Text(
                  l10n.paoSectionTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _paoValueController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.paoValueLabel,
                          hintText: '6',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _paoUnit,
                        decoration: InputDecoration(
                          labelText: l10n.unitLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'months',
                            child: Text(l10n.unitMonths),
                          ),
                          DropdownMenuItem(
                            value: 'days',
                            child: Text(l10n.unitDays),
                          ),
                          DropdownMenuItem(
                            value: 'hours',
                            child: Text(l10n.unitHours),
                          ),
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
                              ? formatDateByLocale(context, _openedDate!)
                              : l10n.openedDateBtn,
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
                                : l10n.timeBtn,
                          ),
                          onPressed: _selectOpenedTime,
                        ),
                      ),
                    ],
                    if (_openedDate != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: l10n.clearOpenedDate,
                        onPressed: () => setState(() => _openedDate = null),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // === KHU VỰC 4: CHỦ SỞ HỮU (DÙNG WIDGET TÁI SỬ DỤNG) ===
                TagSelectorSection(
                  title: l10n.ownerSectionTitle,
                  options: _availableOwners,
                  selectedValue: _selectedOwner,
                  labelBuilder: (owner) => localizeOwner(l10n, owner),
                  addButtonLabel: l10n.newOwner,
                  addButtonIcon: Icons.add,
                  onSelected: (val) => setState(() => _selectedOwner = val),
                  onAddPressed: () => _showAddTagDialog(
                    title: l10n.addNewOwnerTitle,
                    hintText: l10n.addNewOwnerHint,
                    isOwner: true,
                  ),
                ),
                const SizedBox(height: 18),

                // === KHU VỰC 5: VỊ TRÍ CẤT GIỮ (DÙNG WIDGET TÁI SỬ DỤNG) ===
                TagSelectorSection(
                  title: l10n.locationSectionTitle,
                  options: _availableLocations,
                  selectedValue: _selectedLocation,
                  labelBuilder: (loc) => localizeLocation(l10n, loc),
                  addButtonLabel: l10n.newLocation,
                  addButtonIcon: Icons.add_location_alt_outlined,
                  onSelected: (val) => setState(() => _selectedLocation = val),
                  onAddPressed: () => _showAddTagDialog(
                    title: l10n.addNewLocationTitle,
                    hintText: l10n.addNewLocationHint,
                    isOwner: false,
                  ),
                ),
                const SizedBox(height: 22),

                // === KHU VỰC 6: MỐC CẢNH BÁO & LỊCH ĐIỆN THOẠI ===
                AlertsSection(
                  alerts: _alerts,
                  onChanged: (updatedAlerts) {
                    setState(() => _alerts = updatedAlerts);
                  },
                ),
                const SizedBox(height: 18),

                // === KHU VỰC 7: GHI CHÚ ===
                Text(
                  l10n.notesSectionTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.notesHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _saveItem,
              icon: const Icon(Icons.check),
              label: Text(
                _isEditing ? l10n.saveChanges : l10n.addItem,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}