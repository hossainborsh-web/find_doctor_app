import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/cloud/media_service.dart';

/// Shows a built-in asset, a photo stored in Supabase ("media:<id>") or a
/// file on this device.
class FdImage extends StatelessWidget {
  const FdImage(
    this.source, {
    super.key,
    this.isAsset = false,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.placeholder,
  });

  final String source;
  final bool isAsset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final Widget? placeholder;

  Widget _broken(BuildContext context) =>
      placeholder ??
      SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.black26, size: 36),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return _broken(context);
    if (isAsset) {
      return Image.asset(source,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          errorBuilder: (_, __, ___) => _broken(context));
    }
    if (MediaService.isMedia(source)) {
      final cached = MediaService.instance.cached(source);
      if (cached != null) {
        return Image.memory(cached,
            fit: fit,
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _broken(context));
      }
      return FutureBuilder<Uint8List?>(
        future: MediaService.instance.load(source),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            if (snapshot.connectionState == ConnectionState.done) {
              return _broken(context);
            }
            return SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return Image.memory(bytes,
              fit: fit,
              width: width,
              height: height,
              cacheWidth: cacheWidth,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _broken(context));
        },
      );
    }
    if (kIsWeb) return _broken(context);
    return Image.file(File(source),
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) => _broken(context));
  }
}
