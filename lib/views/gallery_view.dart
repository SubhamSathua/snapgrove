import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import '../core/locator.dart';
import '../viewmodels/gallery_view_model.dart';
import '../theme/app_theme.dart';
import '../services/file_service.dart';
import '../services/web_image_utils.dart';
import 'image_preview_view.dart';

// Import SafHelper for native thumbnail access
import '../services/saf_helper_stub.dart'
    if (dart.library.io) '../services/saf_helper_native.dart';

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

class _OrganizerGalleryState extends State<OrganizerGallery> with SingleTickerProviderStateMixin {
  late GalleryViewModel _viewModel;
  bool _isTransitioning = true;

  @override
  void initState() {
    super.initState();
    _viewModel = locator<GalleryViewModel>(param1: widget.path);
    
    // Delay loading until transition finishes for smoother entrance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _isTransitioning = false);
          _viewModel.loadFiles();
        }
      });
    });
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    final sc = context.snapgroveColors;
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sc.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sc.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Quit without saving?',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your temporary selection will be lost.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 14,
                    color: sc.muted,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Stay', style: TextStyle(color: sc.muted)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sc.accent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Quit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim1),
            child: child,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldPop = await _showExitConfirmation(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          final isLoading = _viewModel.isLoading || _isTransitioning;
          
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              cacheExtent: 1000, // Pre-render items outside viewport for smoother scrolling
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
                    onPressed: () async {
                      final shouldPop = await _showExitConfirmation(context);
                      if (shouldPop && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  actions: [
                    if (!isLoading && _viewModel.files.isNotEmpty)
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
                if (isLoading && _viewModel.files.isEmpty)
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
                        (context, index) => const SkeletonLoader(),
                        childCount: 8,
                      ),
                    ),
                  )
                else if (_viewModel.files.isEmpty)
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
                          final path = _viewModel.files[index];
                          return _GalleryItem(
                            path: path,
                            buildImage: () => _buildImage(context, path),
                          );
                        },
                        childCount: _viewModel.files.length,
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage(BuildContext context, String path) {
    if (kIsWeb) {
      return FutureBuilder<String?>(
        key: ValueKey('web_$path'),
        future: WebImageUtils.getThumbnail(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => _ErrorPlaceholder(),
            );
          }
          return const SkeletonLoader(isThumbnail: true);
        },
      );
    }
    if (path.startsWith('content://')) {
      return FutureBuilder<Uint8List?>(
        key: ValueKey('saf_$path'),
        future: SafHelper.getThumbnail(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              cacheWidth: 300,
              cacheHeight: 400,
              gaplessPlayback: true,
            );
          }
          if (snapshot.connectionState == ConnectionState.done && !snapshot.hasData) {
            // Fallback to full read if thumbnail fails
            return FutureBuilder<Uint8List?>(
              future: locator<FileService>().readFile(path),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    cacheHeight: 400,
                  );
                }
                return _ErrorPlaceholder();
              },
            );
          }
          return const SkeletonLoader(isThumbnail: true);
        },
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 300,
      cacheHeight: 400,
      errorBuilder: (context, error, stackTrace) => _ErrorPlaceholder(),
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final String path;
  final Widget Function() buildImage;

  const _GalleryItem({required this.path, required this.buildImage});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImagePreviewView(path: path),
          ),
        );
      },
      child: Container(
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
                child: Hero(
                  tag: path,
                  child: buildImage(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                p.basename(path).replaceAll('%2F', '/').split('/').last,
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
      ),
    );
  }
}

class SkeletonLoader extends StatefulWidget {
  final bool isThumbnail;
  const SkeletonLoader({super.key, this.isThumbnail = false});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final baseColor = sc.surfaceMuted;
    final highlightColor = sc.surfaceElevated;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: widget.isThumbnail ? null : BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    return Container(
      color: sc.surfaceMuted,
      child: Center(child: Icon(Icons.broken_image, color: sc.muted)),
    );
  }
}
