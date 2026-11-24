import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import '../services/item_repository.dart';
import '../services/package_scanner_service.dart';
import '../widgets/alerts_section.dart';
import '../widgets/tag_selector_section.dart';

class AddEditScreen extends StatefulWidget {
  final HouseholdItem? existingItem;
  final bool isDuplicate;

  const AddEditScreen({
    super.key,
    this.existingItem,
    this.isDuplicate = false,
  });

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  static const List<int> _paoMonthPresets = [3, 6, 12, 24];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _paoValueController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;

  late String _selectedCategory;
  bool _userManuallySelectedCategory = false;
  DateTime? _expiryDate;
  bool _showExpiryError = false;

  late bool _paoEnabled;
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
  PackageScanMode? _scanningMode;
  bool get _isScanning => _scanningMode != null;
  List<String> _suggestedNames = const [];
  List<ScannedDateCandidate> _suggestedDates = const [];

  bool get _isEditing => widget.existingItem != null && !widget.isDuplicate;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _nameController.addListener(_onNameChanged);
    _paoValueController = TextEditingController(
      text: item?.paoValue?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: item?.quantity?.toString() ?? '',
    );
    _notesController = TextEditingController(text: item?.notes ?? '');

    _selectedCategory = item?.category ?? AppConstants.defaultCategories.first;
    _expiryDate = widget.isDuplicate ? null : item?.expiryDate;
    _openedDate = widget.isDuplicate ? null : item?.openedDate;
    _paoUnit = item?.paoUnit ?? 'months';
    _paoEnabled = (item?.paoValue != null && item!.paoValue! > 0) ||
        (!widget.isDuplicate && item?.openedDate != null);

    _selectedOwner = item?.owner;
    _selectedLocation = item?.location;

    _alerts = item != null
        ? item.alerts
            .map(
              (a) => widget.isDuplicate
                  ? a.copyWith(clearCalendarEventId: true)
                  : a,
            )
            .toList()
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
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _paoValueController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    _applyAutoCategory(_nameController.text);
  }

  void _applyAutoCategory(String sourceText, {String? directCategory}) {
    if (_isEditing || _userManuallySelectedCategory) return;
    final detected = directCategory ??
        PackageScannerService.instance.classifyCategoryFromText(sourceText);
    if (detected != null && detected != _selectedCategory) {
      setState(() => _selectedCategory = detected);
    }
  }

  // --- BỘ ĐIỀU KHIỂN TĂNG / GIẢM SỐ LƯỢNG 1 CHẠM ---
  void _adjustQuantity(int delta) {
    final current = int.tryParse(_quantityController.text.trim());
    final int? next;
    if (current == null) {
      next = delta > 0 ? 1 : null;
    } else {
      final candidate = current + delta;
      next = candidate <= 0 ? null : candidate;
    }

    setState(() {
      final text = next?.toString() ?? '';
      _quantityController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  // --- TÍNH XEM TRƯỚC HẠN DÙNG THỰC TẾ KHI BẬT PAO ---
  DateTime? _calculatePaoPreview() {
    if (!_paoEnabled || _openedDate == null) return null;
    final paoValue = int.tryParse(_paoValueController.text.trim());
    if (paoValue == null || paoValue <= 0) return null;

    final DateTime paoExpiry;
    switch (_paoUnit) {
      case 'hours':
        paoExpiry = _openedDate!.add(Duration(hours: paoValue));
        break;
      case 'days':
        paoExpiry = _openedDate!.add(Duration(days: paoValue));
        break;
      case 'months':
      default:
        paoExpiry = DateTime(
          _openedDate!.year,
          _openedDate!.month + paoValue,
          _openedDate!.day,
          _openedDate!.hour,
          _openedDate!.minute,
        );
        break;
    }

    if (_expiryDate != null) {
      final endOfExpiryDay = DateTime(
        _expiryDate!.year,
        _expiryDate!.month,
        _expiryDate!.day,
        23,
        59,
      );
      if (endOfExpiryDay.isBefore(paoExpiry)) {
        return _paoUnit == 'hours' ? endOfExpiryDay : _expiryDate;
      }
    }

    return paoExpiry;
  }

  // --- 1. CHỌN ẢNH ĐẠI DIỆN & 2 LUỒNG QUÉT CHUYÊN BIỆT (TÊN / HSD) ---
  Future<void> _pickImage(ImageSource source) async {
    if (_isScanning) return;

    // Chỉ tự động gợi ý tên & phân loại khi chụp/chọn ảnh lần đầu và ô Tên đang trống
    final bool shouldAutoScanName =
        _imageBytes == null && _nameController.text.trim().isEmpty;

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 65,
      );

      if (pickedFile == null || !mounted) return;

      final Uint8List bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageBase64 = base64Encode(bytes);
      });

      if (shouldAutoScanName) {
        setState(() => _scanningMode = PackageScanMode.name);
        try {
          final scanResult = await PackageScannerService.instance
              .scanFrontLabel(pickedFile.path);
          if (!mounted) return;
          if (scanResult.nameSuggestions.isNotEmpty) {
            setState(() => _suggestedNames = scanResult.nameSuggestions);
          }
          if (scanResult.suggestedCategory != null) {
            _applyAutoCategory(
              '',
              directCategory: scanResult.suggestedCategory,
            );
          }
        } finally {
          if (mounted && _scanningMode == PackageScanMode.name) {
            setState(() => _scanningMode = null);
          }
        }
      }
    } catch (_) {
      // Bỏ qua êm ái nếu thiết bị từ chối quyền Camera/Thư viện
    }
  }

  void _showImageSourceSheet() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(sheetContext);
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
                  Navigator.pop(sheetContext);
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

  Future<void> _scanField(ImageSource source, PackageScanMode mode) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      // Ảnh quét tạm giữ độ phân giải cao (2048px) để chữ in phun nhỏ vẫn rõ nét
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFile == null || !mounted) return;

      setState(() => _scanningMode = mode);

      if (mode == PackageScanMode.name) {
        final scanResult = await PackageScannerService.instance
            .scanFrontLabel(pickedFile.path);
        if (!mounted) return;

        if (scanResult.suggestedCategory != null) {
          _applyAutoCategory(
            '',
            directCategory: scanResult.suggestedCategory,
          );
        }

        if (scanResult.nameSuggestions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.scanNameNoResult)),
          );
        } else {
          setState(() => _suggestedNames = scanResult.nameSuggestions);
        }
      } else {
        final dates = await PackageScannerService.instance
            .scanExpiryDate(pickedFile.path);
        if (!mounted) return;

        if (dates.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.scanExpiryNoResult)),
          );
        } else {
          setState(() {
            _suggestedDates = dates;
            _expiryDate = dates.first.date;
            _showExpiryError = false;
          });
        }
      }
    } catch (_) {
      // Bỏ qua êm ái nếu thiết bị từ chối quyền Camera/Thư viện
    } finally {
      if (mounted) setState(() => _scanningMode = null);
    }
  }

  void _showScanSheet(PackageScanMode mode) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(sheetContext);
                _scanField(ImageSource.camera, mode);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _scanField(ImageSource.gallery, mode);
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
          _showExpiryError = false;
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
          decoration: InputDecoration(hintText: hintText),
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
    final isFormValid = _formKey.currentState!.validate();

    if (_expiryDate == null) {
      setState(() => _showExpiryError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectExpiryDateError)),
      );
      return;
    }

    if (!isFormValid) return;

    final int? parsedPao =
        _paoEnabled ? int.tryParse(_paoValueController.text.trim()) : null;

    final savedItem = HouseholdItem(
      id: _isEditing ? widget.existingItem!.id : null,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      expiryDate: _expiryDate!,
      openedDate: _paoEnabled ? _openedDate : null,
      paoValue: (parsedPao != null && parsedPao > 0) ? parsedPao : null,
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

  // --- THÀNH PHẦN GIAO DIỆN PHỤ TRỢ ---
  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainer
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(isDark ? 90 : 140),
        ),
      ),
      child: child,
    );
  }

  Widget _buildScanButton({
    required PackageScanMode mode,
    required String tooltip,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isThisScanning = _scanningMode == mode;

    return IconButton(
      tooltip: tooltip,
      onPressed: _isScanning ? null : () => _showScanSheet(mode),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer.withAlpha(145),
        foregroundColor: colorScheme.primary,
        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: isThisScanning
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          : const Icon(Icons.document_scanner_outlined, size: 20),
    );
  }

  Widget _buildQuantityStepper(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final currentQty = int.tryParse(_quantityController.text.trim());

    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.quantityLabel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onPressed: currentQty != null ? () => _adjustQuantity(-1) : null,
                icon: const Icon(Icons.remove),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: '1',
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                color: colorScheme.primary,
                onPressed: () => _adjustQuantity(1),
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm');
    final paoPreview = _calculatePaoPreview();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        title: Text(
          widget.isDuplicate
              ? l10n.duplicateItem
              : (_isEditing ? l10n.editItem : l10n.addNewItem),
        ),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: l10n.duplicateItem,
              onPressed: () => Navigator.pop(context, 'duplicate'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: l10n.delete,
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isDuplicate) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy_outlined,
                          size: 18,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.duplicateHint,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // === KHU VỰC 1: ẢNH SẢN PHẨM ===
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceSheet,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withAlpha(85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.primary.withAlpha(90),
                                  width: 1.2,
                                ),
                              ),
                              child: _imageBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(19),
                                      child: Image.memory(
                                        _imageBytes!,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 30,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          l10n.addPhoto,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            if (_imageBytes != null)
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.surfaceContainerLow,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!_isEditing && _imageBytes == null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.photoScanHint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // === THẺ 1: THÔNG TIN CHÍNH (BẮT BUỘC) ===
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: l10n.itemNameLabel,
                          hintText: l10n.itemNameHint,
                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(6),
                            child: _buildScanButton(
                              mode: PackageScanMode.name,
                              tooltip: l10n.scanNameTooltip,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.itemNameError;
                          }
                          return null;
                        },
                      ),
                      if (_suggestedNames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.suggestedNamesLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _suggestedNames.map((suggested) {
                            return ActionChip(
                              avatar: Icon(
                                Icons.auto_awesome,
                                size: 15,
                                color: colorScheme.primary,
                              ),
                              label: Text(
                                suggested,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                _nameController.text = suggested;
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: l10n.categoryLabel,
                              ),
                              items: AppConstants.defaultCategories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(
                                    localizeCategory(l10n, cat),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCategory = value;
                                    _userManuallySelectedCategory = true;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 9,
                            child: _buildQuantityStepper(l10n, colorScheme),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Ô chọn Ngày hết hạn tách rõ vùng chọn lịch & nút quét ML Kit
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showExpiryError
                                ? colorScheme.error
                                : (_expiryDate != null
                                    ? colorScheme.primary.withAlpha(110)
                                    : colorScheme.outlineVariant),
                            width: _showExpiryError ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(11),
                                ),
                                onTap: () => _selectDate(isExpiryDate: true),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 20,
                                        color: _showExpiryError
                                            ? colorScheme.error
                                            : (_expiryDate != null
                                                ? colorScheme.primary
                                                : colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.expiryDateLabel,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _showExpiryError
                                                    ? colorScheme.error
                                                    : colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _expiryDate != null
                                                  ? formatDateByLocale(
                                                      context,
                                                      _expiryDate!,
                                                    )
                                                  : l10n.tapToSelectDate,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: _expiryDate != null
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: _expiryDate != null
                                                    ? colorScheme.onSurface
                                                    : (_showExpiryError
                                                        ? colorScheme.error
                                                        : colorScheme.primary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: colorScheme.outlineVariant,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: _buildScanButton(
                                mode: PackageScanMode.expiryDate,
                                tooltip: l10n.scanExpiryTooltip,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_suggestedDates.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.suggestedDatesLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _suggestedDates.map((candidate) {
                            final dateLabel =
                                formatDateByLocale(context, candidate.date);
                            final chipText = candidate.isExplicitExpiry
                                ? '$dateLabel (HSD)'
                                : dateLabel;

                            return ActionChip(
                              avatar: Icon(
                                Icons.event_available,
                                size: 15,
                                color: colorScheme.primary,
                              ),
                              label: Text(
                                chipText,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() {
                                  _expiryDate = candidate.date;
                                  _showExpiryError = false;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // === THẺ 2: HẠN SAU MỞ NẮP (PAO - BẬT/TẮT GỌN GÀNG) ===
                _buildSectionCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        secondary: Icon(
                          Icons.lock_open_outlined,
                          color: _paoEnabled
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          l10n.paoSectionTitle,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          l10n.paoSwitchSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        value: _paoEnabled,
                        onChanged: (enabled) {
                          setState(() => _paoEnabled = enabled);
                        },
                      ),
                      if (_paoEnabled) ...[
                        const Divider(height: 16),
                        // Chip chọn nhanh các mốc PAO phổ biến (3M / 6M / 12M / 24M)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _paoMonthPresets.map((months) {
                            final isSelected = _paoUnit == 'months' &&
                                _paoValueController.text.trim() == '$months';
                            return ChoiceChip(
                              label: Text('${months}M'),
                              selected: isSelected,
                              visualDensity: VisualDensity.compact,
                              selectedColor: colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurface,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _paoUnit = 'months';
                                  _paoValueController.text = '$months';
                                  _openedDate ??= DateTime.now();
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _paoValueController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: l10n.paoValueLabel,
                                  hintText: '6',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _paoUnit,
                                decoration: InputDecoration(
                                  labelText: l10n.unitLabel,
                                  isDense: true,
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
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _openedDate != null
                                      ? formatDateByLocale(
                                          context,
                                          _openedDate!,
                                        )
                                      : l10n.openedDateBtn,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () =>
                                    _selectDate(isExpiryDate: false),
                              ),
                            ),
                            if (_paoUnit == 'hours') ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    side: BorderSide(
                                      color: colorScheme.outlineVariant,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
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
                                onPressed: () =>
                                    setState(() => _openedDate = null),
                              ),
                          ],
                        ),
                        if (paoPreview != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer
                                  .withAlpha(140),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.paoEffectivePreview(
                                      formatDateByLocale(
                                        context,
                                        paoPreview,
                                        includeTime: _paoUnit == 'hours',
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // === THẺ 3: CHỦ SỞ HỮU, VỊ TRÍ & GHI CHÚ ===
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TagSelectorSection(
                        title: l10n.ownerSectionTitle,
                        options: _availableOwners,
                        selectedValue: _selectedOwner,
                        labelBuilder: (owner) => localizeOwner(l10n, owner),
                        addButtonLabel: l10n.newOwner,
                        addButtonIcon: Icons.add,
                        onSelected: (val) =>
                            setState(() => _selectedOwner = val),
                        onAddPressed: () => _showAddTagDialog(
                          title: l10n.addNewOwnerTitle,
                          hintText: l10n.addNewOwnerHint,
                          isOwner: true,
                        ),
                      ),
                      const Divider(height: 24),
                      TagSelectorSection(
                        title: l10n.locationSectionTitle,
                        options: _availableLocations,
                        selectedValue: _selectedLocation,
                        labelBuilder: (loc) => localizeLocation(l10n, loc),
                        addButtonLabel: l10n.newLocation,
                        addButtonIcon: Icons.add_location_alt_outlined,
                        onSelected: (val) =>
                            setState(() => _selectedLocation = val),
                        onAddPressed: () => _showAddTagDialog(
                          title: l10n.addNewLocationTitle,
                          hintText: l10n.addNewLocationHint,
                          isOwner: false,
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        l10n.notesSectionTitle,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
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
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // === THẺ 4: MỐC CẢNH BÁO & LỊCH ĐIỆN THOẠI ===
                _buildSectionCard(
                  child: AlertsSection(
                    alerts: _alerts,
                    onChanged: (updatedAlerts) {
                      setState(() => _alerts = updatedAlerts);
                    },
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
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withAlpha(150),
              ),
            ),
          ),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saveItem,
              icon: const Icon(Icons.check),
              label: Text(
                _isEditing ? l10n.saveChanges : l10n.addItem,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}