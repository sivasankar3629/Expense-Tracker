import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account.dart';
import '../models/expense.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/category_picker.dart';
import '../widgets/paid_from_picker.dart';
import '../widgets/currency_scope.dart';

/// What happened on the form, so the caller can react (e.g. offer undo).
enum ExpenseFormResult { saved, deleted }

/// Adds a new expense, or edits [initial] when given. Saves straight to [store].
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.store,
    this.initial,
    this.initialCategoryId,
    this.draft,
    this.draftSource,
    this.onSaved,
  });

  final ExpenseStore store;
  final Expense? initial;

  /// Pre-fills a new expense, e.g. from a bank SMS; saving adds it.
  final Expense? draft;

  /// Where [draft] came from, shown above the form, e.g. the SMS text.
  final String? draftSource;

  /// Called with the expense once it's saved.
  final ValueChanged<Expense>? onSaved;

  /// Pre-selects a category for a new expense, e.g. when adding from that
  /// category's screen.
  final String? initialCategoryId;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  /// What the fields start with: the expense being edited, or a draft.
  late final Expense? _prefill = widget.initial ?? widget.draft;
  late final _titleController = TextEditingController(text: _prefill?.title);
  late final _amountController = TextEditingController(
    text: _prefill == null ? null : _editableAmount(_prefill.amount),
  );
  late final _notesController = TextEditingController(text: _prefill?.notes);

  late DateTime _date = DateUtils.dateOnly(_prefill?.dateTime ?? DateTime.now());
  late TimeOfDay _time = TimeOfDay.fromDateTime(_prefill?.dateTime ?? DateTime.now());
  late Account _account = _initialAccount();
  // Dropped if the category has since been deleted.
  late String? _categoryId =
      widget.store.categoryById(_prefill?.categoryId ?? widget.initialCategoryId)?.id;

  bool get _isEditing => widget.initial != null;

  /// A draft that leaves the title to the user, e.g. from a bank SMS: the
  /// rest is filled in, so typing the title is all that's left.
  bool get _titleFirst => widget.draft != null && widget.draft!.title.isEmpty;

  Account _initialAccount() {
    final prefill = _prefill;
    if (prefill == null) return widget.store.lastUsedAccount;
    return widget.store.accountById(prefill.accountId) ?? Account.cash;
  }

  /// "12" rather than "12.0", and "180.50" rather than "180.5".
  static String _editableAmount(double amount) =>
      amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final expense = Expense(
      id: widget.initial?.id,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      notes: _notesController.text.trim(),
      accountId: _account.id,
      categoryId: _categoryId,
      dateTime: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
    );
    if (_isEditing) {
      widget.store.updateExpense(expense);
    } else {
      widget.store.addExpense(expense);
    }
    widget.onSaved?.call(expense);
    Navigator.of(context).pop(ExpenseFormResult.saved);
  }

  void _delete() {
    widget.store.deleteExpense(widget.initial!);
    Navigator.of(context).pop(ExpenseFormResult.deleted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.displayMedium?.copyWith(
      fontSize: 48,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.8,
      color: theme.colorScheme.primary,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit expense' : 'Add expense'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  // Keep every FormField mounted while the wrapped chips grow,
                  // so validation still checks fields scrolled out of view.
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.draftSource case final source?) ...[
                          _DraftSource(source),
                          const SizedBox(height: 12),
                        ],
                        // Amount first and large: it's the one field every expense needs.
                        TextFormField(
                          controller: _amountController,
                          // Pop the keyboard up for blank new expenses only; editing
                          // starts with just looking, and a draft with its title.
                          autofocus: _prefill == null,
                          style: amountStyle,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            hintText: '0',
                            hintStyle: amountStyle?.copyWith(
                              color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            ),
                            labelStyle: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            fillColor: Color.lerp(
                              theme.colorScheme.surfaceContainerLow,
                              theme.colorScheme.primary,
                              0.08,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary.withValues(alpha: 0.16),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                            ),
                            prefixText: context.currencyPrefix,
                            prefixStyle: amountStyle,
                            contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                          autofocus: _titleFirst,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            prefixIcon: Icon(Icons.edit_outlined),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Enter a title' : null,
                        ),
                        const SizedBox(height: 16),
                        CategoryPicker(
                          store: widget.store,
                          selectedId: _categoryId,
                          onChanged: (id) => setState(() => _categoryId = id),
                        ),
                        const SizedBox(height: 16),
                        PaidFromPicker(
                          store: widget.store,
                          selected: _account,
                          onChanged: (account) => setState(() => _account = account),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _PickerField(
                                label: 'Date',
                                value: formatDayLabel(_date),
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
                          minLines: 2,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Pinned below the fields so it's always in reach, and rides just
                // above the keyboard while typing.
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: Text(_isEditing ? 'Save' : 'Add'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  ),
                ),
              ],
            ),
          ),
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
  });

  final String label;
  final String value;
  final Widget leading;
  final VoidCallback onTap;

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
        ),
        // Shrinks a little rather than cutting off on narrow phones.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, maxLines: 1),
        ),
      ),
    );
  }
}

/// The SMS a draft was read from, so the user can check it against the form.
class _DraftSource extends StatelessWidget {
  const _DraftSource(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sms_outlined, size: 18, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
