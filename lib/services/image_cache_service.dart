import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef BaseDirProvider = Future<Directory> Function();

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  Dio dio = Dio();
  BaseDirProvider baseDirProvider = getApplicationDocumentsDirectory;

  Future<String> _dirPath() async {
    final dir = await baseDirProvider();
    final img = Directory(p.join(dir.path, 'images'));
    if (!await img.exists()) await img.create(recursive: true);
    return img.path;
  }

  Future<String?> cachedPathForId(String id) async {
    final dir = await _dirPath();
    for (final ext in const ['png', 'jpg', 'jpeg', 'webp']) {
      final f = File(p.join(dir, '$id.$ext'));
      if (await f.exists()) return f.path;
    }
    return null;
  }

  Future<bool> isCached(String id) async => (await cachedPathForId(id)) != null;

  Future<String> _tempPath(String id) async {
    final dir = await _dirPath();
    return p.join(dir, '.$id.part');
  }

  String _extFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) return 'png';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return ext;
      default:
        return 'png';
    }
  }

  Future<String> download(String id, String url) async {
    final ext = _extFromUrl(url);
    final dir = await _dirPath();
    final out = p.join(dir, '$id.$ext');
    final temp = await _tempPath(id);
    final tf = File(temp);
    if (await tf.exists()) await tf.delete();
    await dio.download(url, temp);
    final of = File(out);
    if (await of.exists()) await of.delete();
    await File(temp).rename(out);
    return out;
  }
}

