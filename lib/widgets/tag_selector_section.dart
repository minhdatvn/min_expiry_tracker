import 'package:flutter/material.dart';

// Widget dùng chung cho các khu vực chọn thẻ (Chủ sở hữu, Vị trí...)
class TagSelectorSection extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selectedValue;
  final String Function(String value) labelBuilder;
  final String addButtonLabel;
  final IconData addButtonIcon;
  final ValueChanged<String?> onSelected;
  final VoidCallback onAddPressed;

  const TagSelectorSection({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.labelBuilder,
    required this.addButtonLabel,
    required this.addButtonIcon,
    required this.onSelected,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...options.map((item) {
              final isSelected = selectedValue == item;
              return ChoiceChip(
                label: Text(labelBuilder(item)),
                selected: isSelected,
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
                side: BorderSide(
                  color: isSelected
                      ? colorScheme.primary.withAlpha(140)
                      : colorScheme.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (selected) {
                  onSelected(selected ? item : null);
                },
              );
            }),
            // Nút hành động thêm mới được tô màu nhấn để tách biệt hẳn với dữ liệu
            ActionChip(
              avatar: Icon(
                addButtonIcon,
                size: 17,
                color: colorScheme.primary,
              ),
              label: Text(
                addButtonLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              backgroundColor: colorScheme.primaryContainer.withAlpha(85),
              side: BorderSide(
                color: colorScheme.primary.withAlpha(120),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onPressed: onAddPressed,
            ),
          ],
        ),
      ],
    );
  }
}