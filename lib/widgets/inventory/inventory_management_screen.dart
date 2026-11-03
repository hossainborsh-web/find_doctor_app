import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_style.dart';
import '../../core/theme/fd_palette.dart';
import '../../core/widgets/fd_widgets.dart';
import '../../prototype/prototype_session.dart';
import '../../services/inventory_service.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({
    super.key,
    required this.title,
    required this.category,
  });

  final String title;
  final String category;

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final InventoryService _inventoryService = InventoryService();
  late List<Map<String, dynamic>> _items;
  late final String _hospital;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _hospital = context.read<PrototypeSession>().workplace;
    _items = _inventoryService.getItemsByCategory(widget.category,
        hospital: _hospital);
    _inventoryService.addListener(_handleInventoryChanged);
    _inventoryService.load();
  }

  @override
  void didUpdateWidget(covariant InventoryManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _refreshItems();
    }
  }

  @override
  void dispose() {
    _inventoryService.removeListener(_handleInventoryChanged);
    super.dispose();
  }

  void _handleInventoryChanged() {
    if (!mounted) return;
    setState(() {
      _items = _inventoryService.getItemsByCategory(widget.category,
          hospital: _hospital);
    });
  }

  void _refreshItems() {
    final refreshedItems = _inventoryService
        .getItemsByCategory(widget.category, hospital: _hospital);
    setState(() => _items = refreshedItems);
  }

  Future<void> _openItemForm({Map<String, dynamic>? item}) async {
    final draft = await showDialog<_InventoryItemDraft>(
      context: context,
      builder: (_) => _InventoryItemDialog(
        initialCategory: item?['category']?.toString() ?? widget.category,
        item: item,
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _isWorking = true);
    final saved = await _inventoryService.saveItem(
      id: item?['id']?.toString(),
      name: draft.name,
      category: draft.category,
      stock: draft.stock,
      unit: draft.unit,
      hospital: _hospital,
      expiryDate: draft.expiryDate,
    );
    if (!mounted) return;
    setState(() => _isWorking = false);
    _showMessage(saved
        ? item == null
            ? 'Inventory item added.'
            : 'Inventory item updated.'
        : 'The inventory item could not be saved.');
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final itemName = item['name']?.toString() ?? 'this item';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete inventory item?'),
        content: Text('Remove $itemName from this inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isWorking = true);
    final deleted = await _inventoryService.deleteItem(item['id'].toString());
    if (!mounted) return;
    setState(() => _isWorking = false);
    _showMessage(deleted
        ? 'Inventory item deleted.'
        : 'The inventory item could not be deleted.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  FdStatusTone _toneFor(String status) {
    if (status == 'Critical') return FdStatusTone.danger;
    if (status == 'Low Stock') return FdStatusTone.warning;
    if (status == 'In Stock') return FdStatusTone.success;
    return FdStatusTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final totalStock = _items.fold<int>(
      0,
      (total, item) => total + ((item['stock'] as num?)?.toInt() ?? 0),
    );
    final attentionCount = _items
        .where((item) =>
            item['status'] == 'Low Stock' || item['status'] == 'Critical')
        .length;

    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox.expand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InventoryTopBar(
                    title: widget.title,
                    onBack: () => Navigator.of(context).maybePop(),
                    onRefresh: _isWorking ? null : _refreshItems,
                  ),
                  if (_isWorking) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        const FdPreviewNotice(
                            message:
                                'Inventory updates stay on this device and are not synced.'),
                        const SizedBox(height: 16),
                        _InventorySummary(
                          itemCount: _items.length,
                          totalStock: totalStock,
                          attentionCount: attentionCount,
                        ),
                        const SizedBox(height: 22),
                        FdSectionHeader(title: '${widget.title} items'),
                        if (_items.isEmpty)
                          const FdEmptyState(
                            title: 'No inventory items yet',
                            message:
                                'Add an item to begin tracking this category.',
                            icon: Icons.inventory_2_outlined,
                          )
                        else
                          for (final item in _items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _InventoryItemCard(
                                item: item,
                                tone:
                                    _toneFor(item['status']?.toString() ?? ''),
                                onEdit: _isWorking
                                    ? null
                                    : () => _openItemForm(item: item),
                                onDelete:
                                    _isWorking ? null : () => _deleteItem(item),
                              ),
                            ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: context.fdColor(Colors.white),
                      border: Border(
                        top: BorderSide(
                            color: context.fdColor(AppColors.borderGrey)),
                      ),
                    ),
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isWorking ? null : () => _openItemForm(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add inventory item'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryTopBar extends StatelessWidget {
  const _InventoryTopBar({
    required this.title,
    required this.onBack,
    required this.onRefresh,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.fdColor(Colors.white),
        border: Border(
            bottom: BorderSide(color: context.fdColor(AppColors.borderGrey))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headline2.copyWith(
                fontSize: 18,
                color: context.fdColor(AppColors.primaryBlueDark),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh inventory',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _InventorySummary extends StatelessWidget {
  const _InventorySummary({
    required this.itemCount,
    required this.totalStock,
    required this.attentionCount,
  });

  final int itemCount;
  final int totalStock;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    return FdCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(label: 'Items', value: '$itemCount'),
          ),
          Container(
              width: 1,
              height: 38,
              color: context.fdColor(AppColors.borderGrey)),
          Expanded(
            child: _SummaryValue(label: 'Total stock', value: '$totalStock'),
          ),
          Container(
              width: 1,
              height: 38,
              color: context.fdColor(AppColors.borderGrey)),
          Expanded(
            child: _SummaryValue(
              label: 'Needs attention',
              value: '$attentionCount',
              valueColor: attentionCount > 0 ? AppColors.warningOrange : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.headline2.copyWith(
            color: valueColor ?? context.fdColor(AppColors.primaryBlueDark),
            fontSize: 21,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  const _InventoryItemCard({
    required this.item,
    required this.tone,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final FdStatusTone tone;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Inventory item';
    final category = item['category']?.toString() ?? 'Uncategorized';
    final status = item['status']?.toString() ?? 'Unknown';
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final unit = item['unit']?.toString() ?? 'units';
    final rawExpiry = item['expiryDate']?.toString() ?? '';
    final expiryDate = rawExpiry.isEmpty ? 'not set' : rawExpiry;

    return FdCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 10, 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.fdColor(AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: context.fdColor(AppColors.primaryBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyText2
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(category, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FdStatusChip(label: status, tone: tone),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Icon(Icons.inventory_outlined,
                  size: 17, color: context.fdColor(AppColors.darkGrey)),
              const SizedBox(width: 7),
              Text('$stock $unit', style: AppTextStyles.bodyText2),
              const SizedBox(width: 18),
              Icon(Icons.event_outlined,
                  size: 17, color: context.fdColor(AppColors.darkGrey)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Expires $expiryDate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
              IconButton(
                tooltip: 'Edit item',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              IconButton(
                tooltip: 'Delete item',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                color: AppColors.errorRed,
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryItemDialog extends StatefulWidget {
  const _InventoryItemDialog({required this.initialCategory, this.item});

  final String initialCategory;
  final Map<String, dynamic>? item;

  @override
  State<_InventoryItemDialog> createState() => _InventoryItemDialogState();
}

class _InventoryItemDialogState extends State<_InventoryItemDialog> {
  static const _categories = [
    'Medication',
    'PPE & Consumables',
    'Equipment',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _stockController;
  late final TextEditingController _unitController;
  late final TextEditingController _expiryController;
  late String _category;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?['name']?.toString());
    _stockController = TextEditingController(
      text: item?['stock']?.toString() ?? '',
    );
    _unitController = TextEditingController(text: item?['unit']?.toString());
    _expiryController = TextEditingController(
      text: item?['expiryDate']?.toString() ?? '',
    );
    _category = _categories.contains(widget.initialCategory)
        ? widget.initialCategory
        : _categories.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Enter $label.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit inventory item' : 'Add inventory item'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) => _required(value, 'an item name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Quantity in stock',
                    prefixIcon: Icon(Icons.numbers_outlined),
                  ),
                  validator: (value) {
                    final error = _required(value, 'a quantity');
                    if (error != null) return error;
                    if (int.tryParse(value!.trim()) == null) {
                      return 'Enter a valid whole number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'Boxes, packs, vials',
                    prefixIcon: Icon(Icons.straighten_outlined),
                  ),
                  validator: (value) => _required(value, 'a unit'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expiryController,
                  decoration: const InputDecoration(
                    labelText: 'Expiry date (optional)',
                    hintText: 'e.g. 12 Oct 2027',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _InventoryItemDraft(
                name: _nameController.text.trim(),
                category: _category,
                stock: int.parse(_stockController.text.trim()),
                unit: _unitController.text.trim(),
                expiryDate: _expiryController.text.trim(),
              ),
            );
          },
          child: Text(_isEditing ? 'Save changes' : 'Add item'),
        ),
      ],
    );
  }
}

class _InventoryItemDraft {
  const _InventoryItemDraft({
    required this.name,
    required this.category,
    required this.stock,
    required this.unit,
    required this.expiryDate,
  });

  final String name;
  final String category;
  final int stock;
  final String unit;
  final String expiryDate;
}
