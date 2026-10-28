import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account.dart';
import '../models/expense.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/account_icon.dart';
import '../widgets/account_picker_sheet.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _date = DateUtils.dateOnly(DateTime.now());
  late TimeOfDay _time = TimeOfDay.now();
  late Account _account = widget.store.lastUsedAccount;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickAccount() async {
    final picked = await showAccountPicker(
      context,
      store: widget.store,
      selected: _account,
    );
    if (picked != null) setState(() => _account = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Expense(
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text),
        notes: _notesController.text.trim(),
        accountId: _account.id,
        dateTime: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _time.hour,
          _time.minute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Amount first and large: it's the one field every expense needs.
            TextFormField(
              controller: _amountController,
              autofocus: true,
              style: amountStyle,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                prefixStyle: amountStyle,
                contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              ),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            _PickerField(
              label: 'Paid from',
              value: _account.nickname,
              leading: AccountIcon(_account.type, size: 28),
              onTap: _pickAccount,
              showChevron: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'Date',
                    value: formatDate(_date),
                    leading: const Icon(Icons.calendar_today_outlined),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerField(
                    label: 'Time',
                    value: _time.format(context),
                    leading: const Icon(Icons.schedule_outlined),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens a picker when tapped.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.leading,
    required this.onTap,
    this.showChevron = false,
  });

  final String label;
  final String value;
  final Widget leading;
  final VoidCallback onTap;

  /// Hints that tapping opens a list; skipped on narrow fields to save room.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(widthFactor: 1, heightFactor: 1, child: leading),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          suffixIcon: showChevron ? const Icon(Icons.expand_more) : null,
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
