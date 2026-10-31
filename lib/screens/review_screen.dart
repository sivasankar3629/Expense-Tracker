import 'package:flutter/material.dart';

import '../sms/sms_detection.dart';
import '../sms/sms_parser.dart';
import '../utils/format.dart';
import '../widgets/currency_scope.dart';
import '../widgets/expense_list.dart';

/// Spends found in bank SMS, each waiting for Add (opens the filled-in form)
/// or Ignore.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.detection});

  final SmsDetection detection;

  Future<void> _ignoreAll(BuildContext context) async {
    final count = detection.pending.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ignore all $count?'),
        content: const Text('They won’t be added. New ones will still show up here.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Ignore all')),
        ],
      ),
    );
    if (confirmed == true) detection.ignoreAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([detection, detection.store]),
      builder: (context, _) {
        final pending = detection.pending;
        return Scaffold(
          appBar: AppBar(
            title: const Text('To review'),
            actions: [
              if (pending.length > 1)
                TextButton(onPressed: () => _ignoreAll(context), child: const Text('Ignore all')),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: detection.scan,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text(
                    'Found in your bank SMS. Add the ones that are expenses; nothing is added until you do.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (pending.isEmpty)
                  const EmptyMessage(
                    icon: Icons.mark_email_read_outlined,
                    title: 'All caught up',
                    message: 'New spends from bank SMS will show up here.',
                  )
                else
                  for (final t in pending) ...[
                    _DetectedCard(detection: detection, transaction: t),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetectedCard extends StatelessWidget {
  const _DetectedCard({required this.detection, required this.transaction});

  final SmsDetection detection;
  final DetectedTransaction transaction;

  void _add(BuildContext context) => openDetectedSpend(context, detection, transaction);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final t = transaction;
    final account = detection.accountFor(t);
    final source = account?.nickname ??
        [t.senderName, if (t.accountHint case final hint?) '${t.isCard ? 'card' : 'a/c'} ••$hint'].join(' ');
    final duplicate = detection.possibleDuplicate(t);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(t.isCard ? Icons.credit_card_outlined : Icons.account_balance_outlined, color: muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.merchant ?? (t.isCard ? 'Card payment' : 'Payment'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$source · ${formatDayLabel(t.date)}, ${TimeOfDay.fromDateTime(t.date).format(context)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.formatAmount(t.amount),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (duplicate != null)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You may have added this already: “${duplicate.title}”',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => detection.ignore(t), child: const Text('Ignore')),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the add form filled in from [t]; saving it takes [t] off the list.
/// The title is left for the user to type, since the payee is rarely what
/// they'd call it ("Flipkart" for new shoes); the payee is a tap away.
void openDetectedSpend(BuildContext context, SmsDetection detection, DetectedTransaction t) {
  ExpenseActions.addDraft(
    context,
    detection.store,
    detection.draftFor(t).copyWith(title: ''),
    source: '${t.senderName}: ${t.body}',
    suggestedTitle: t.merchant,
    onSaved: (expense) => detection.added(t, expense),
  );
}

/// On Home while there's something to review.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(Icons.sms_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1 ? '1 spend to review' : '$count spends to review',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'Found in your bank SMS',
                      style: text.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
