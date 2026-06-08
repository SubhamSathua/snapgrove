import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import '../core/locator.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';

class ImagePreviewView extends StatelessWidget {
  final String path;

  const ImagePreviewView({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/Back-Btn.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          p.basename(path).replaceAll('%2F', '/').split('/').last,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: Hero(
          tag: path,
          child: _buildImage(context),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    // For both Web and Android (SAF), we use the FileService.readFile
    if (kIsWeb || path.startsWith('content://')) {
      return FutureBuilder<Uint8List?>(
        future: locator<FileService>().readFile(path),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
            );
          }
          if (snapshot.hasError) {
            return const Icon(Icons.broken_image, size: 100, color: Colors.white);
          }
          return const CircularProgressIndicator(color: Colors.white);
        },
      );
    }
    
    // Regular desktop/local file access
    return Image.file(
      File(path),
      fit: BoxFit.contain,
    );
  }
}
