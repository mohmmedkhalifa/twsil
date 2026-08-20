import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return CachedNetworkTileImage(url: url, coordinates: coordinates);
  }
}

class CachedNetworkTileImage extends ImageProvider<CachedNetworkTileImage> {
  final String url;
  final TileCoordinates coordinates;

  const CachedNetworkTileImage({required this.url, required this.coordinates});

  @override
  Future<CachedNetworkTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedNetworkTileImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(CachedNetworkTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }

  Future<Codec> _loadAsync(CachedNetworkTileImage key, ImageDecoderCallback decode) async {
    try {
      final cacheDir = Directory('${Directory.systemTemp.path}/map_tiles_cache');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      final fileName = '${key.coordinates.z}_${key.coordinates.x}_${key.coordinates.y}.png';
      final file = File('${cacheDir.path}/$fileName');

      if (file.existsSync() && file.lengthSync() > 0) {
        final bytes = await file.readAsBytes();
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      }

      final request = await HttpClient().getUrl(Uri.parse(key.url));
      request.headers.add('User-Agent', 'com.twsil.mobile');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      await file.writeAsBytes(bytes, flush: true);

      final buffer = await ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (_) {
      final request = await HttpClient().getUrl(Uri.parse(key.url));
      request.headers.add('User-Agent', 'com.twsil.mobile');
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      final buffer = await ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedNetworkTileImage &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}
