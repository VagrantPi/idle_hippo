import 'package:flutter/services.dart';

/// Default asset loader that relies on Flutter's bundled assets.
/// Used on platforms without dart:io (e.g., web).
Future<String> loadAssetString(String path) async {
  return rootBundle.loadString(path);
}

