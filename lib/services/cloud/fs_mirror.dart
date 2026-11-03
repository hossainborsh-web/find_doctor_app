import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef JsonMap = Map<String, dynamic>;

/// Writes one changed item. [before] is the stored version (null when new).
typedef MirrorWrite = void Function(
  WriteBatch batch,
  DocumentReference<JsonMap> ref,
  JsonMap now,
  JsonMap? before,
);

/// JSON with sorted keys, so local and stored versions compare equal.
String canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is Iterable) return value.map(_canonical).toList();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value;
}

/// Keeps [list] in step with one or more Firestore queries on [collection],
/// and writes local changes back.
///
/// Services keep working with plain Dart lists: they change items in place,
/// add or remove them, then call [push]. Only items whose JSON changed are
/// written; items removed from [list] are deleted. Writes are not awaited, so
/// the app stays responsive offline; Firestore's local cache shows them at
/// once and syncs when online.
class FsMirror<T> {
  FsMirror({
    required this.collection,
    required this.list,
    required this.idOf,
    required this.toJson,
    required this.fromJson,
    required this.onChange,
    this.write,
  });

  final String collection;
  final List<T> list;
  final String Function(T item) idOf;
  final JsonMap Function(T item) toJson;
  final T Function(String id, JsonMap json) fromJson;
  final VoidCallback onChange;
  final MirrorWrite? write;

  // What was last read or written, per document: the raw stored JSON (to skip
  // unchanged snapshots) and the item's own JSON (to spot local changes, even
  // when the stored copy lacks fields the app fills with defaults).
  final Map<String, String> _remote = {};
  final Map<String, String> _synced = {};
  final Map<String, JsonMap> _syncedData = {};
  final Map<int, Set<String>> _idsByQuery = {};
  final List<StreamSubscription<QuerySnapshot<JsonMap>>> _subscriptions = [];
  Completer<void> _ready = Completer<void>()..complete();

  CollectionReference<JsonMap> get ref =>
      FirebaseFirestore.instance.collection(collection);

  /// Completes once every query has delivered its first result.
  Future<void> get ready => _ready.future;

  bool get isListening => _subscriptions.isNotEmpty;

  /// Starts (or restarts) listening. Clears what was there before.
  void listen(List<Query<JsonMap>> queries) {
    stop();
    list.clear();
    _remote.clear();
    _synced.clear();
    _syncedData.clear();
    _idsByQuery.clear();
    _ready = Completer<void>();
    if (queries.isEmpty) {
      _ready.complete();
      onChange();
      return;
    }
    var waiting = queries.length;
    void firstDone() {
      waiting--;
      if (waiting <= 0 && !_ready.isCompleted) _ready.complete();
    }

    for (var i = 0; i < queries.length; i++) {
      final index = i;
      _idsByQuery[index] = <String>{};
      var first = true;
      _subscriptions.add(queries[i].snapshots().listen(
        (snapshot) {
          _apply(index, snapshot);
          if (first) {
            first = false;
            firstDone();
          }
          onChange();
        },
        onError: (Object error) {
          debugPrint('Find Doctor sync ($collection): $error');
          if (first) {
            first = false;
            firstDone();
          }
        },
      ));
    }
  }

  void _apply(int index, QuerySnapshot<JsonMap> snapshot) {
    final ids = _idsByQuery[index]!;
    for (final change in snapshot.docChanges) {
      final id = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        ids.remove(id);
        final elsewhere = _idsByQuery.values.any((set) => set.contains(id));
        if (!elsewhere) {
          _remote.remove(id);
          _synced.remove(id);
          _syncedData.remove(id);
          list.removeWhere((item) => idOf(item) == id);
        }
        continue;
      }
      ids.add(id);
      final data = change.doc.data();
      if (data == null) continue;
      final json = canonicalJson(data);
      final at = list.indexWhere((item) => idOf(item) == id);
      if (at >= 0 && _remote[id] == json) continue;
      final T item;
      final JsonMap local;
      try {
        item = fromJson(id, data);
        local = toJson(item);
      } catch (error) {
        debugPrint('Find Doctor sync ($collection/$id) skipped: $error');
        continue;
      }
      _remote[id] = json;
      _synced[id] = canonicalJson(local);
      _syncedData[id] = local;
      if (at >= 0) {
        list[at] = item;
      } else {
        list.add(item);
      }
    }
  }

  /// Writes what changed since the last sync and deletes removed items.
  /// Each document is written on its own, so one refused write (security
  /// rules) never blocks the others.
  Future<void> push() async {
    final db = FirebaseFirestore.instance;
    void commit(WriteBatch batch, String id) {
      unawaited(batch.commit().catchError((Object error) {
        debugPrint('Find Doctor save ($collection/$id) failed: $error');
      }));
    }

    final present = <String>{};
    for (final item in list) {
      final id = idOf(item);
      present.add(id);
      final data = toJson(item);
      final json = canonicalJson(data);
      if (_synced[id] == json) continue;
      final before = _syncedData[id];
      final batch = db.batch();
      if (write != null) {
        write!(batch, ref.doc(id), data, before);
      } else {
        batch.set(ref.doc(id), data);
      }
      _remote[id] = json;
      _synced[id] = json;
      _syncedData[id] = data;
      commit(batch, id);
    }
    for (final id
        in _synced.keys.where((id) => !present.contains(id)).toList()) {
      _remote.remove(id);
      _synced.remove(id);
      _syncedData.remove(id);
      for (final set in _idsByQuery.values) {
        set.remove(id);
      }
      commit(db.batch()..delete(ref.doc(id)), id);
    }
  }

  void stop() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
