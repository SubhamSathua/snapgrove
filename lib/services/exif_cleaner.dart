import 'dart:typed_data';

class ExifCleaner {
  static Uint8List stripMetadata(Uint8List bytes, String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    if (ext == 'jpg' || ext == 'jpeg') {
      return _stripJpeg(bytes);
    } else if (ext == 'png') {
      return _stripPng(bytes);
    } else if (ext == 'webp') {
      return _stripWebp(bytes);
    }
    return bytes;
  }

  static Uint8List _stripJpeg(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return bytes;
    }

    final out = BytesBuilder();
    out.add([0xFF, 0xD8]); // SOI

    int i = 2;
    while (i < bytes.length) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }

      int marker = bytes[i + 1];
      if (marker == 0xFF) {
        i++;
        continue;
      }

      // Standalone markers
      if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
        out.add([0xFF, marker]);
        i += 2;
        continue;
      }

      // Start of scan - compressed data follows until EOI
      if (marker == 0xDA) {
        out.add(bytes.sublist(i));
        break;
      }

      if (i + 3 >= bytes.length) break;
      int length = (bytes[i + 2] << 8) | bytes[i + 3];
      int segmentEnd = i + 2 + length;
      if (segmentEnd > bytes.length) segmentEnd = bytes.length;

      // APP1 (EXIF: 0xE1), APP2 (ICC: 0xE2), APP13 (Photoshop: 0xED), COM (Comment: 0xFE)
      if (marker == 0xE1 || marker == 0xFE || marker == 0xED || (marker >= 0xE2 && marker <= 0xEF)) {
        // Skip metadata marker
        i = segmentEnd;
      } else {
        // Keep JFIF (APP0: 0xE0), DQT, SOF, DHT, etc.
        out.add(bytes.sublist(i, segmentEnd));
        i = segmentEnd;
      }
    }

    return out.toBytes();
  }

  static Uint8List _stripPng(Uint8List bytes) {
    if (bytes.length < 8) return bytes;
    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (int j = 0; j < 8; j++) {
      if (bytes[j] != pngSignature[j]) return bytes;
    }

    final out = BytesBuilder();
    out.add(pngSignature);

    int i = 8;
    while (i + 8 <= bytes.length) {
      int length = (bytes[i] << 24) | (bytes[i + 1] << 16) | (bytes[i + 2] << 8) | bytes[i + 3];
      int typeStart = i + 4;
      String type = String.fromCharCodes(bytes.sublist(typeStart, typeStart + 4));
      int chunkTotal = 12 + length;
      int chunkEnd = i + chunkTotal;
      if (chunkEnd > bytes.length) chunkEnd = bytes.length;

      // Metadata chunks to strip
      const stripChunks = {'eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME', 'dSIG', 'prWm'};
      if (stripChunks.contains(type)) {
        i = chunkEnd;
      } else {
        out.add(bytes.sublist(i, chunkEnd));
        i = chunkEnd;
      }
    }

    return out.toBytes();
  }

  static Uint8List _stripWebp(Uint8List bytes) {
    if (bytes.length < 12) return bytes;
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final webp = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || webp != 'WEBP') return bytes;

    final out = BytesBuilder();
    int i = 12;
    final validChunks = <int>[];

    while (i + 8 <= bytes.length) {
      String chunkType = String.fromCharCodes(bytes.sublist(i, i + 4));
      int chunkSize = bytes[i + 4] | (bytes[i + 5] << 8) | (bytes[i + 6] << 16) | (bytes[i + 7] << 24);
      int paddedSize = (chunkSize + 1) & ~1;
      int chunkEnd = i + 8 + paddedSize;
      if (chunkEnd > bytes.length) chunkEnd = bytes.length;

      if (chunkType == 'EXIF' || chunkType == 'XMP ') {
        i = chunkEnd;
      } else {
        validChunks.addAll(bytes.sublist(i, chunkEnd));
        i = chunkEnd;
      }
    }

    out.add(bytes.sublist(0, 4));
    int newRiffSize = 4 + validChunks.length;
    out.add([
      newRiffSize & 0xFF,
      (newRiffSize >> 8) & 0xFF,
      (newRiffSize >> 16) & 0xFF,
      (newRiffSize >> 24) & 0xFF,
    ]);
    out.add(bytes.sublist(8, 12));
    out.add(validChunks);

    return out.toBytes();
  }
}
