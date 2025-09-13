import 'dart:io';
import 'package:flutter/services.dart';

/// Asset loader with filesystem fallback for test environments.
/// Tries rootBundle first; if it fails, reads from the project filesystem.
Future<String> loadAssetString(String path) async {
  try {
    return await rootBundle.loadString(path);
  } catch (_) {
    // Support flutter test (without bundled assets) by reading from disk.
    return File(path).readAsString();
  }
}

