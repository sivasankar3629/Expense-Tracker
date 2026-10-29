import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import 'category_icon.dart';

/// Creates a category, or edits [initial] when given. Returns the saved
/// category, or null if cancelled.
Future<ExpenseCategory?> showCategoryDialog(
  BuildContext context, {
  required ExpenseStore store,
  ExpenseCategory? initial,
}) {
  return showDialog<ExpenseCategory>(
    context: context,
    builder: (_) => _CategoryDialog(store: store, initial: initial),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.store, this.initial});

  final ExpenseStore store;
  final ExpenseCategory? initial;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initial?.name);
  late String _iconKey = widget.initial?.iconKey ?? 'tag';
  // New categories get the next colour round the palette, so a few in a row
  // don't all look the same.
  late int _color = widget.initial?.colorValue ??
      categoryColors[widget.store.categories.length % categoryColors.length];

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final initial = widget.initial;
    final ExpenseCategory saved;
    if (initial == null) {
      saved = widget.store.addCategory(name: name, iconKey: _iconKey, colorValue: _color);
    } else {
      saved = initial.copyWith(name: name, iconKey: _iconKey, colorValue: _color);
      widget.store.updateCategory(saved);
    }
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = Color(_color);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit category' : 'New category'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryIcon(icon: categoryIcons[_iconKey]!, color: color, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Food',
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) return 'Enter a name';
                        if (widget.store.isCategoryNameTaken(name, exceptId: widget.initial?.id)) {
                          return 'You already have this category';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Colour', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in categoryColors)
                    _Swatch(
                      color: Color(value),
                      selected: value == _color,
                      onTap: () => setState(() => _color = value),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Icon', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final MapEntry(key: key, value: icon) in categoryIcons.entries)
                    _IconChoice(
                      icon: icon,
                      color: color,
                      selected: key == _iconKey,
                      onTap: () => setState(() => _iconKey = key),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Icon(icon, size: 22, color: selected ? color : muted),
      ),
    );
  }
}
