import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/saf_helper_stub.dart'
    if (dart.library.io) 'services/saf_helper_native.dart';
import 'main.dart';

class OrganizerGallery extends StatefulWidget {
  final String path;
  final String title;

  const OrganizerGallery({
    super.key,
    required this.path,
    this.title = 'Organizer Gallery',
  });

  @override
  State<OrganizerGallery> createState() => _OrganizerGalleryState();
}

class _OrganizerGalleryState extends State<OrganizerGallery> {
  List<String> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (widget.path.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        _files = List.generate(12, (i) => 'Web Screenshot $i');
      } else if (Platform.isAndroid) {
        _files = await SafHelper.listImages(widget.path);
      } else {
        final dir = Directory(widget.path);
        if (await dir.exists()) {
          _files = dir
              .listSync()
              .where((f) =>
                  f is File &&
                  (f.path.toLowerCase().endsWith('.png') || 
                   f.path.toLowerCase().endsWith('.jpg') ||
                   f.path.toLowerCase().endsWith('.jpeg')))
              .map((f) => f.path)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading files: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/Back-Btn.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.white : Colors.black,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (!_loading && _files.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Organize'),
                    style: TextButton.styleFrom(
                      foregroundColor: sc.accent,
                      textStyle: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_files.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 48, color: sc.muted.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'No screenshots found.',
                      style: TextStyle(fontFamily: 'Lora', color: sc.muted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final path = _files[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: sc.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sc.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: _buildImage(path),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              path.split('/').last.split('%2F').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: sc.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: _files.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String path) {
    if (kIsWeb) {
      return Container(
        color: context.snapgroveColors.surfaceMuted,
        child: Center(child: Icon(Icons.image, color: context.snapgroveColors.muted)),
      );
    }
    if (path.startsWith('content://')) {
      return FutureBuilder<Uint8List?>(
        future: SafHelper.readFile(path),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          return Container(color: context.snapgroveColors.surfaceMuted);
        },
      );
    }
    return Image.file(File(path), fit: BoxFit.cover);
  }
}
