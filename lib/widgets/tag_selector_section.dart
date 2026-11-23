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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...options.map((item) {
              final isSelected = selectedValue == item;
              return ChoiceChip(
                label: Text(labelBuilder(item)),
                selected: isSelected,
                onSelected: (selected) {
                  onSelected(selected ? item : null);
                },
              );
            }),
            ActionChip(
              avatar: Icon(addButtonIcon, size: 18),
              label: Text(addButtonLabel),
              onPressed: onAddPressed,
            ),
          ],
        ),
      ],
    );
  }
}