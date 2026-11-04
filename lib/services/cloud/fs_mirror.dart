import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cloud_db.dart';

export 'cloud_db.dart'
    show
        CloudDb,
        CollectionReference,
        DocumentReference,
        FieldPath,
        FieldValue,
        JsonMap,
        Query,
        WriteBatch;

/// Writes one changed item. [before] is the stored version (null when new).
typedef MirrorWrite = void Function(
  WriteBatch batch,
  DocumentReference ref,
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
  if (value is DateTime) return value.toIso8601String();
  return value;
}

/// Keeps [list] in step with one or more queries on [collection] in
/// Supabase, and writes local changes back.
///
/// Services keep working with plain Dart lists: they change items in place,
/// add or remove them, then call [push]. Only items whose JSON changed are
/// written; items removed from [list] are deleted. The queries are checked
/// again every [pollEvery], so changes made on other devices appear within a
/// few seconds. A fresh local change is never overwritten by an older copy
/// from the server.
class FsMirror<T> {
  FsMirror({
    required this.collection,
    required this.list,
    required this.idOf,
    required this.toJson,
    required this.fromJson,
    required this.onChange,
    this.write,
    this.pollEvery = const Duration(seconds: 5),
  });

  final String collection;
  final List<T> list;
  final String Function(T item) idOf;
  final JsonMap Function(T item) toJson;
  final T Function(String id, JsonMap json) fromJson;
  final VoidCallback onChange;
  final MirrorWrite? write;
  final Duration pollEvery;

  // What was last read or written, per document: the raw stored JSON (to skip
  // unchanged results) and the item's own JSON (to spot local changes, even
  // when the stored copy lacks fields the app fills with defaults).
  final Map<String, String> _remote = {};
  final Map<String, String> _synced = {};
  final Map<String, JsonMap> _syncedData = {};
  final Map<int, Set<String>> _idsByQuery = {};

  // Local writes: a counter that ticks on every write, the tick of each
  // document's last local change, and writes still on their way.
  int _tick = 0;
  final Map<String, int> _changedAt = {};
  final Map<String, int> _inFlight = {};

  List<Query> _queries = const [];
  Timer? _timer;
  bool _polling = false;
  int _generation = 0;
  Completer<void> _ready = Completer<void>()..complete();

  CollectionReference get ref => CloudDb.instance.collection(collection);

  /// Completes once every query has delivered its first result.
  Future<void> get ready => _ready.future;

  bool get isListening => _queries.isNotEmpty;

  /// True once every query has loaded successfully since the last [listen]
  /// (false while offline), so callers don't treat "couldn't load" as "empty".
  bool get loadedOk => _loadedOk;
  bool _loadedOk = false;

  /// Starts (or restarts) listening. Clears what was there before.
  void listen(List<Query> queries) {
    stop();
    _generation++;
    list.clear();
    _remote.clear();
    _synced.clear();
    _syncedData.clear();
    _idsByQuery.clear();
    _changedAt.clear();
    _loadedOk = false;
    _queries = List.of(queries);
    _ready = Completer<void>();
    if (queries.isEmpty) {
      _ready.complete();
      onChange();
      return;
    }
    for (var i = 0; i < queries.length; i++) {
      _idsByQuery[i] = <String>{};
    }
    _poll(first: true);
    _timer = Timer.periodic(pollEvery, (_) => _poll());
  }

  /// Checks the server now (e.g. when a screen opens).
  Future<void> refresh() => _poll();

  Future<void> _poll({bool first = false}) async {
    if (_polling || _queries.isEmpty) {
      if (first && !_ready.isCompleted) _ready.complete();
      return;
    }
    _polling = true;
    final generation = _generation;
    // Keep this listen's own completer: if listen() restarts while this poll
    // is still waiting, it must not mark the new listen as ready.
    final ready = _ready;
    final startedAt = _tick;
    var changed = false;
    var allOk = true;
    try {
      for (var i = 0; i < _queries.length; i++) {
        try {
          final snapshot = await _queries[i].get();
          if (generation != _generation) return;
          changed |= _apply(i, snapshot.docs, startedAt);
        } catch (error) {
          allOk = false;
          debugPrint('Find Doctor sync ($collection): $error');
        }
      }
      if (generation == _generation && allOk) _loadedOk = true;
    } finally {
      if (generation == _generation) _polling = false;
      // Never leaves anyone waiting, and never touches a newer listen's one.
      if (!ready.isCompleted) ready.complete();
    }
    if (changed || first) onChange();
  }

  /// True when the local copy of [id] is newer than a result that was
  /// requested at [startedAt].
  bool _locallyNewer(String id, int startedAt) =>
      (_inFlight[id] ?? 0) > 0 || (_changedAt[id] ?? -1) > startedAt;

  bool _apply(int index, List<DocumentSnapshot> docs, int startedAt) {
    var changed = false;
    final ids = _idsByQuery[index]!;
    final seen = <String>{};
    for (final doc in docs) {
      final id = doc.id;
      final data = doc.data();
      if (data == null) continue;
      seen.add(id);
      ids.add(id);
      if (_locallyNewer(id, startedAt)) continue;
      final json = canonicalJson(data);
      final at = list.indexWhere((item) => idOf(item) == id);
      if (at >= 0 && _remote[id] == json) continue;
      if (at < 0 && _synced.containsKey(id) && _remote[id] == json) continue;
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
      changed = true;
    }
    // Documents this query no longer returns (deleted, or no longer allowed).
    for (final id in ids.difference(seen).toList()) {
      ids.remove(id);
      if (_locallyNewer(id, startedAt)) continue;
      final elsewhere = _idsByQuery.values.any((set) => set.contains(id));
      if (elsewhere) continue;
      _remote.remove(id);
      _synced.remove(id);
      _syncedData.remove(id);
      final before = list.length;
      list.removeWhere((item) => idOf(item) == id);
      if (list.length != before) changed = true;
    }
    return changed;
  }

  /// Writes what changed since the last sync and deletes removed items.
  /// Each document is written on its own, so one refused write (security
  /// rules) never blocks the others. If the server refuses a write, the next
  /// check brings back the server's version.
  Future<void> push() async {
    void commit(WriteBatch batch, String id) {
      _changedAt[id] = ++_tick;
      _inFlight[id] = (_inFlight[id] ?? 0) + 1;
      unawaited(batch.commit().catchError((Object error) {
        debugPrint('Find Doctor save ($collection/$id) failed: $error');
        // Let the next check restore what the server has.
        _remote.remove(id);
        _synced.remove(id);
        _syncedData.remove(id);
      }).whenComplete(() {
        _inFlight[id] = (_inFlight[id] ?? 1) - 1;
        _changedAt[id] = ++_tick;
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
      final batch = WriteBatch();
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
      commit(WriteBatch()..delete(ref.doc(id)), id);
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _queries = const [];
    _polling = false;
  }
}
