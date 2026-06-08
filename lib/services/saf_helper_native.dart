import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_stream/saf_stream.dart';

class SafHelper {
  static final _safStream = SafStream();
  
  static Future<List<String>> listImages(String uri) async {
    try {
      // SafUtil 3.1.0 uses 'list'
      final contents = await SafUtil().list(uri);
      return contents
          .where((f) {
            if (f.isDir) return false;
            final name = f.name.toLowerCase();
            return name.endsWith('.png') || 
                   name.endsWith('.jpg') || 
                   name.endsWith('.jpeg') ||
                   name.endsWith('.webp');
          })
          .map((f) => f.uri)
          .toList();
    } catch (e) {
      debugPrint('SAF Error: listImages failed: $e');
      return [];
    }
  }

  static Future<Uint8List?> readFile(String uri) async {
    try {
      // SafStream 3.0.0 uses 'readFileBytes'
      return await _safStream.readFileBytes(uri);
    } catch (e) {
      debugPrint('SAF Error: readFile failed: $e');
      return null;
    }
  }
}
