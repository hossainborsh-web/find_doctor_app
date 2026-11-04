import 'package:flutter/material.dart';

import 'account_service.dart';
import 'cloud/fs_mirror.dart';

/// Hospital stock: medication, equipment and consumables, with low-stock
/// status. Kept in Supabase per hospital.
class InventoryService extends ChangeNotifier {
  // Singleton pattern implementation
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;
  InventoryService._internal();

  /// Every item the signed-in manager can see. Each item carries the
  /// hospital it belongs to.
  final List<Map<String, dynamic>> _inventoryItems = [];
  late final FsMirror<Map<String, dynamic>> _mirror =
      FsMirror<Map<String, dynamic>>(
    collection: 'inventory',
    list: _inventoryItems,
    idOf: (item) => item['id'].toString(),
    toJson: (item) => Map<String, dynamic>.from(item),
    fromJson: (id, json) => {...json, 'id': id},
    onChange: notifyListeners,
  );
  bool _attached = false;

  /// General Managers see every hospital's stock; hospital staff see theirs.
  void attach(AppAccount me) {
    final items = CloudDb.instance.collection('inventory');
    final staff = AccountService.isHr(me) || me.practises;
    _attached = true;
    _mirror.listen([
      if (AccountService.isGeneralManager(me))
        items
      else if (staff && me.hospital.trim().isNotEmpty)
        items.where('hospital', isEqualTo: me.hospital.trim()),
    ]);
  }

  void detach() {
    _attached = false;
    _mirror.listen(const []);
  }

  /// Waits for the first data.
  Future<void> load() async {
    if (_attached) await _mirror.ready;
  }

  Future<void> _persist() async {
    notifyListeners();
    await _mirror.push();
  }

  static String _hospitalKey(String hospital) => hospital.trim().toLowerCase();

  bool _belongsTo(Map<String, dynamic> item, String hospital) =>
      _hospitalKey(item['hospital']?.toString() ?? '') ==
      _hospitalKey(hospital);

  /// Items of [hospital] (all categories).
  List<Map<String, dynamic>> itemsFor(String hospital) => _inventoryItems
      .where((item) => _belongsTo(item, hospital))
      .toList(growable: false);

  /// Items of [hospital] in [category] ('Medication', 'PPE & Consumables',
  /// 'Equipment' or 'All').
  List<Map<String, dynamic>> getItemsByCategory(String category,
      {String hospital = ''}) {
    return _inventoryItems
        .where((item) =>
            _belongsTo(item, hospital) &&
            (category == 'All' ||
                item['category'] == category ||
                // The equipment screen also lists consumables (gloves, masks).
                (category == 'Equipment' &&
                    item['category'] == 'PPE & Consumables')))
        .toList(growable: false);
  }

  /// Low-stock and critical items of [hospital].
  List<Map<String, dynamic>> lowStockFor(String hospital) => itemsFor(hospital)
      .where((item) => item['status'] != 'In Stock')
      .toList(growable: false);

  /// Add or update an inventory item
  Future<bool> saveItem({
    String? id,
    required String name,
    required String category,
    required int stock,
    required String unit,
    String hospital = '',
    String expiryDate = '',
  }) async {
    await load();
    final status =
        stock < 10 ? 'Critical' : (stock < 20 ? 'Low Stock' : 'In Stock');

    if (id != null && id.isNotEmpty) {
      for (final item in _inventoryItems) {
        if (item['id'] != id) continue;
        item['name'] = name.trim();
        item['category'] = category;
        item['stock'] = stock;
        item['unit'] = unit.trim();
        item['status'] = status;
        item['expiryDate'] = expiryDate.trim();
        await _persist();
        return true;
      }
      return false;
    }
    _inventoryItems.add({
      'id': 'inv_${DateTime.now().microsecondsSinceEpoch}',
      'hospital': hospital.trim(),
      'name': name.trim(),
      'category': category,
      'stock': stock,
      'unit': unit.trim(),
      'status': status,
      'expiryDate': expiryDate.trim(),
    });
    await _persist();
    return true;
  }

  /// Delete an inventory item
  Future<bool> deleteItem(String id) async {
    await load();
    final initialLength = _inventoryItems.length;
    _inventoryItems.removeWhere((i) => i['id'] == id);
    if (_inventoryItems.length == initialLength) return false;
    await _persist();
    return true;
  }
}
