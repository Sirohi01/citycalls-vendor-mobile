import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

// Building blocks shared by the job-execution screens (inspection, work
// progress, parts, estimate, invoice, completion) so they all read the same:
// labelled white cards, one sticky action bar at the bottom, one line-item
// sheet.

String formatRupees(num amount) {
  final whole = amount.round().abs().toString();
  // Indian grouping: last three digits, then pairs (12,34,567).
  final head = whole.length > 3 ? whole.substring(0, whole.length - 3) : '';
  final tail = whole.length > 3 ? whole.substring(whole.length - 3) : whole;
  final grouped = head.isEmpty
      ? tail
      : '${head.replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},')},$tail';
  return '${amount < 0 ? '-' : ''}₹$grouped';
}

/// Red inline message shown above a submit button.
class InlineError extends StatelessWidget {
  final String? text;
  const InlineError(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.urgent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.urgent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.urgent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text!,
                style: const TextStyle(
                    color: AppColors.urgent, fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Soft tinted note with an icon — instructions at the top of a screen.
class InfoNote extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const InfoNote(this.text,
      {super.key,
      this.icon = Icons.info_outline_rounded,
      this.color = AppColors.green});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.slate700)),
          ),
        ],
      ),
    );
  }
}

/// Spinner sized for the inside of a filled button.
class ButtonSpinner extends StatelessWidget {
  final Color color;
  const ButtonSpinner({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: color));
}

/// White bar pinned to the bottom of a screen, above the system inset.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8))
        ],
      ),
      child: child,
    );
  }
}

/// "Total  ₹1,200" row for the top of a BottomActionBar.
class TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  const TotalRow({super.key, this.label = 'Total', required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
          Text(formatRupees(amount),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}

/// One part / estimate / invoice line in a list.
class LineItemTile extends StatelessWidget {
  final String name;
  final int qty;
  final double unitPrice;
  final VoidCallback? onRemove;
  const LineItemTile(
      {super.key,
      required this.name,
      required this.qty,
      required this.unitPrice,
      this.onRemove});

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('$qty × ${formatRupees(unitPrice)}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          Text(formatRupees(qty * unitPrice),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: AppColors.ink)),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.faint),
              onPressed: onRemove,
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

typedef LineItemInput = ({String name, int qty, double unitPrice});

/// Bottom sheet asking for a name, quantity and unit price. Shared by Parts,
/// Estimate and Invoice — returns null if dismissed.
Future<LineItemInput?> showLineItemSheet(
  BuildContext context, {
  required String title,
  required String nameLabel,
  String? nameHint,
}) {
  return showModalBottomSheet<LineItemInput>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _LineItemSheet(title: title, nameLabel: nameLabel, nameHint: nameHint),
  );
}

class _LineItemSheet extends StatefulWidget {
  final String title;
  final String nameLabel;
  final String? nameHint;
  const _LineItemSheet(
      {required this.title, required this.nameLabel, this.nameHint});

  @override
  State<_LineItemSheet> createState() => _LineItemSheetState();
}

class _LineItemSheetState extends State<_LineItemSheet> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Enter the ${widget.nameLabel.toLowerCase()}.');
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Quantity must be 1 or more.');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = 'Enter a valid price.');
      return;
    }
    Navigator.of(context).pop((name: name, qty: qty, unitPrice: price));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.ink)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                  labelText: widget.nameLabel, hintText: widget.nameHint),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                        labelText: 'Unit price',
                        prefixIcon:
                            Icon(Icons.currency_rupee_rounded, size: 18)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InlineError(_error),
            FilledButton(onPressed: _save, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}
