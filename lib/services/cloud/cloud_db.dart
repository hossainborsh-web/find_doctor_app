import 'dart:convert';

import 'supabase_api.dart';

// ===========================================================================
// Documents in Supabase, used through a small collection/doc API:
//
//   CloudDb.instance.collection('visits').doc(id).get() / set() / update()
//   CloudDb.instance.collection('visits').where('doctorEmail', isEqualTo: e)
//   FieldValue.arrayUnion([...]), FieldValue.delete(), FieldPath([...])
//
// Each collection is a table with columns (id, doc); `doc` holds the JSON.
// Whole writes go through the database function fd_set and partial writes
// through fd_patch, both of which run under the caller's security rules.
// ===========================================================================

typedef JsonMap = Map<String, dynamic>;

/// App collection name -> Supabase table.
const Map<String, String> _tables = {
  'users': 'profiles',
  'schedules': 'schedules',
  'chatRequests': 'chat_requests',
  'conversations': 'conversations',
  'notifications': 'notifications',
  'visits': 'visits',
  'slots': 'slots',
  'hrCases': 'hr_cases',
  'inventory': 'inventory',
  'posts': 'posts',
  'follows': 'follows',
  'demo': 'demo',
  'media': 'media',
};

String tableFor(String collection) {
  final table = _tables[collection];
  if (table == null) {
    throw ArgumentError('Unknown collection "$collection"');
  }
  return table;
}

class CloudDb {
  const CloudDb._(this._token);

  /// Acts as whoever is signed in on this device.
  static const CloudDb instance = CloudDb._(null);

  /// Acts as the person who owns [session] (demo loader).
  factory CloudDb.as(CloudSessionTokens session) =>
      CloudDb._(() async => session.accessToken);

  final TokenSource? _token;

  CollectionReference collection(String name) =>
      CollectionReference._(this, name);
}

/// A field path for nested keys, e.g. FieldPath(['lastRead', email]).
class FieldPath {
  const FieldPath(this.segments);
  const FieldPath._id() : segments = const ['__id__'];

  /// Filters on the document id.
  static const FieldPath documentId = FieldPath._id();

  final List<String> segments;

  bool get isDocumentId => identical(this, documentId);
}

/// Special values for update(): merge into arrays or remove a field.
class FieldValue {
  const FieldValue._(this.op, [this.items = const []]);

  static FieldValue arrayUnion(List<Object?> items) =>
      FieldValue._('union', items);
  static FieldValue arrayRemove(List<Object?> items) =>
      FieldValue._('remove', items);
  static FieldValue delete() => const FieldValue._('delete');

  final String op;
  final List<Object?> items;
}

class _Filter {
  const _Filter(this.key, this.value);
  final String key;
  final String value;
}

class Query {
  const Query._(this.db, this.collection, [this._filters = const []]);

  final CloudDb db;
  final String collection;
  final List<_Filter> _filters;

  String get table => tableFor(collection);

  Query where(
    Object field, {
    Object? isEqualTo,
    Object? arrayContains,
    Object? isGreaterThanOrEqualTo,
  }) {
    final isId = field is FieldPath && field.isDocumentId;
    final name = field is FieldPath ? field.segments.join(',') : '$field';
    final filters = [..._filters];
    if (isEqualTo != null) {
      filters.add(_Filter(isId ? 'id' : 'doc->>$name', 'eq.${_scalar(isEqualTo)}'));
    }
    if (arrayContains != null) {
      filters.add(_Filter('doc->$name', 'cs.${jsonEncode([arrayContains])}'));
    }
    if (isGreaterThanOrEqualTo != null) {
      filters.add(_Filter(
          isId ? 'id' : 'doc->>$name', 'gte.${_scalar(isGreaterThanOrEqualTo)}'));
    }
    return Query._(db, collection, filters);
  }

  static String _scalar(Object value) =>
      value is DateTime ? value.toIso8601String() : '$value';

  /// Identifies the query (used to compare queries).
  String get key => '$table?${_queryString()}';

  String _queryString() => [
        'select=id,doc',
        for (final filter in _filters)
          '${Uri.encodeQueryComponent(filter.key)}='
              '${Uri.encodeQueryComponent(filter.value)}',
      ].join('&');

  Future<QuerySnapshot> get() async {
    final rows =
        await SupaRest.select(table, _queryString(), token: db._token);
    return QuerySnapshot._([
      for (final row in rows)
        DocumentSnapshot._(
          row['id'] as String,
          (row['doc'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
        ),
    ]);
  }
}

class CollectionReference extends Query {
  const CollectionReference._(CloudDb db, String collection)
      : super._(db, collection);

  DocumentReference doc(String id) => DocumentReference._(db, collection, id);
}

class QuerySnapshot {
  const QuerySnapshot._(this.docs);
  final List<DocumentSnapshot> docs;
}

class DocumentSnapshot {
  const DocumentSnapshot._(this.id, this._data);

  final String id;
  final JsonMap? _data;

  bool get exists => _data != null;
  JsonMap? data() => _data;
}

class DocumentReference {
  const DocumentReference._(this.db, this.collection, this.id);

  final CloudDb db;
  final String collection;
  final String id;

  String get table => tableFor(collection);

  Future<DocumentSnapshot> get() async {
    final rows = await SupaRest.select(
      table,
      'select=id,doc&id=eq.${Uri.encodeQueryComponent(id)}',
      token: db._token,
    );
    if (rows.isEmpty) return DocumentSnapshot._(id, null);
    return DocumentSnapshot._(
        id, (rows.first['doc'] as Map?)?.cast<String, dynamic>() ?? {});
  }

  /// Writes the whole document (creates it when missing).
  Future<void> set(JsonMap data) => SupaRest.rpc(
        'fd_set',
        {'p_table': table, 'p_id': id, 'p_doc': _plain(data)},
        token: db._token,
      );

  /// Creates the document; fails with 'already-exists' if it is there.
  Future<void> create(JsonMap data) => SupaRest.insert(
        table,
        {'id': id, 'doc': _plain(data)},
        token: db._token,
      );

  /// Changes some fields. Keys are field names ("a.b" for nested) or
  /// [FieldPath]s; values may be [FieldValue]s.
  Future<void> update(Map<Object, Object?> changes) {
    final ops = <JsonMap>[];
    changes.forEach((key, value) {
      final path = key is FieldPath ? key.segments : '$key'.split('.');
      if (value is FieldValue) {
        ops.add({
          'op': value.op,
          'path': path,
          if (value.op != 'delete') 'value': _plain(value.items),
        });
      } else {
        ops.add({'op': 'set', 'path': path, 'value': _plain(value)});
      }
    });
    if (ops.isEmpty) return Future.value();
    return SupaRest.rpc(
      'fd_patch',
      {'p_table': table, 'p_id': id, 'p_ops': ops},
      token: db._token,
    );
  }

  Future<void> delete() => SupaRest.delete(
        table,
        'id=eq.${Uri.encodeQueryComponent(id)}',
        token: db._token,
      );
}

/// Several writes sent one after another (each one is its own request).
class WriteBatch {
  final List<Future<void> Function()> _writes = [];

  void set(DocumentReference ref, JsonMap data) =>
      _writes.add(() => ref.set(data));

  void update(DocumentReference ref, Map<Object, Object?> changes) =>
      _writes.add(() => ref.update(changes));

  void delete(DocumentReference ref) => _writes.add(() => ref.delete());

  Future<void> commit() async {
    for (final write in _writes) {
      await write();
    }
  }
}

/// Plain JSON (DateTimes as ISO text, Sets as lists).
Object? _plain(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    return {for (final e in value.entries) '${e.key}': _plain(e.value)};
  }
  if (value is Iterable) return [for (final item in value) _plain(item)];
  return '$value';
}
