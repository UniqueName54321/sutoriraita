import 'package:flutter/services.dart';

/// Android document trees are opaque content URIs, never filesystem paths.
class ProjectDocuments {
  static const channel = MethodChannel('sutoriraita/documents');

  static bool isTree(String root) => root.startsWith('content://');

  static Future<String?> pickTree() => channel.invokeMethod<String>('pickTree');

  static Future<Uint8List?> read(String root, String path) =>
      channel.invokeMethod<Uint8List>('read', {'root': root, 'path': path});

  static Future<void> write(String root, String path, Uint8List bytes) =>
      channel.invokeMethod<void>('write', {
        'root': root,
        'path': path,
        'bytes': bytes,
      });

  static Future<List<String>> list(String root, String path) async =>
      await channel.invokeListMethod<String>('list', {
        'root': root,
        'path': path,
      }) ??
      [];
}
