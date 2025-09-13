// Conditional import: use IO fallback in VM (tests), default to bundle elsewhere.
import 'asset_loader_stub.dart' if (dart.library.io) 'asset_loader_io.dart' as impl;

Future<String> loadAssetString(String path) => impl.loadAssetString(path);

