import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Photos on the free Firebase plan: shrunk to a JPEG and stored in the
/// `media` collection. A post or certificate keeps a "media:<id>" reference.
class MediaService {
  MediaService._();

  static final MediaService instance = MediaService._();
  static const prefix = 'media:';

  /// Firestore documents hold at most 1 MB; stay well under it.
  static const _maxBytes = 700 * 1024;

  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List?>> _loading = {};

  static bool isMedia(String source) => source.startsWith(prefix);

  /// Reads an image file, shrinks it and stores it. Returns "media:<id>".
  Future<String> uploadFile(String path, {int maxSide = 1280}) async {
    final bytes = await File(path).readAsBytes();
    return uploadBytes(bytes, maxSide: maxSide);
  }

  Future<String> uploadBytes(Uint8List bytes, {int maxSide = 1280}) async {
    final jpeg = await compute(_shrink, (bytes, maxSide));
    if (jpeg == null) {
      throw const MediaException('This image could not be read. Try a JPG or PNG.');
    }
    if (jpeg.length > _maxBytes) {
      throw const MediaException('This image is too large even after shrinking.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const MediaException('Sign in first.');
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${Random().nextInt(1 << 20).toRadixString(36)}';
    await FirebaseFirestore.instance.collection('media').doc(id).set({
      'owner': user.uid,
      'mime': 'image/jpeg',
      'data': base64Encode(jpeg),
      'createdAt': DateTime.now().toIso8601String(),
    });
    _cache[id] = jpeg;
    return '$prefix$id';
  }

  /// Bytes of a stored image (cached).
  Future<Uint8List?> load(String source) {
    final id = source.startsWith(prefix) ? source.substring(prefix.length) : source;
    final cached = _cache[id];
    if (cached != null) return SynchronousFuture(cached);
    return _loading[id] ??= _fetch(id);
  }

  Uint8List? cached(String source) {
    final id = source.startsWith(prefix) ? source.substring(prefix.length) : source;
    return _cache[id];
  }

  Future<Uint8List?> _fetch(String id) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('media').doc(id).get();
      final data = doc.data()?['data'];
      if (data is! String) return null;
      final bytes = base64Decode(data);
      _cache[id] = bytes;
      return bytes;
    } catch (error) {
      debugPrint('Find Doctor media $id: $error');
      return null;
    } finally {
      _loading.remove(id);
    }
  }
}

class MediaException implements Exception {
  const MediaException(this.message);
  final String message;

  @override
  String toString() => message;
}

Uint8List? _shrink((Uint8List, int) input) {
  final (bytes, maxSide) = input;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longest = max(image.width, image.height);
  if (longest > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  var quality = 78;
  var jpeg = img.encodeJpg(image, quality: quality);
  while (jpeg.length > 650 * 1024 && quality > 40) {
    quality -= 12;
    jpeg = img.encodeJpg(image, quality: quality);
  }
  return Uint8List.fromList(jpeg);
}
