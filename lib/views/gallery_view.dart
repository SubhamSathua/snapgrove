import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import '../core/locator.dart';
import '../viewmodels/gallery_view_model.dart';
import '../viewmodels/app_view_model.dart';
import '../theme/app_theme.dart';
import '../services/file_service.dart';
import '../services/web_image_utils.dart';
import '../services/thumbnail_manager.dart';
import 'image_preview_view.dart';
import 'landing_page.dart'; // For ThemeDialog

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
  final _thumbnailManager = ThumbnailManager();

  // Grid Configuration
  late int _currentColumns;
  double _lastWidth = 0;
  bool _isWarningOpen = false;

  @override
  void initState() {
    super.initState();
    _viewModel = locator<GalleryViewModel>(param1: widget.path);
    
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    _currentColumns = isMobile ? 3 : 7;

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

  int _getMaxAllowedColumns(double width) {
    if (width < 600) return 5;
    if (width < 1000) return 7;
    return 12;
  }

  void _checkResizeWarning(double width) {
    int maxAllowed = _getMaxAllowedColumns(width);
    if (_currentColumns > maxAllowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showViewDialog(width, isWarning: true);
      });
    }
  }

  Future<void> _showViewDialog(double width, {bool isWarning = false}) async {
    _isWarningOpen = true;
    final sc = context.snapgroveColors;
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final List<int> options = isMobile ? [2, 3, 4, 5] : [3, 4, 5, 6, 7, 10, 12];
    
    // We compute maxAllowed inside the dialog as width might change, 
    // but for the modal we use the triggering width.
    final maxAllowed = _getMaxAllowedColumns(width);

    await showGeneralDialog(
      context: context,
      barrierDismissible: !isWarning,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: sc.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sc.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isWarning ? 'Window Too Narrow' : 'Grid Layout',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isWarning 
                          ? 'Please select a smaller grid size for this window width.'
                          : 'Choose the number of columns',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Lora', fontSize: 14, color: sc.muted),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: options.map((opt) {
                        final isDisabled = opt > maxAllowed;
                        final isActive = _currentColumns == opt;
                        
                        final bgColor = isActive 
                            ? (isDark ? Colors.white : Colors.black)
                            : sc.surfaceMuted;
                        final fgColor = isActive
                            ? (isDark ? Colors.black : Colors.white)
                            : sc.muted;

                        return InkWell(
                          onTap: isDisabled ? null : () {
                            setState(() => _currentColumns = opt);
                            Navigator.of(ctx).pop();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isDisabled ? 0.3 : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: isDisabled ? Colors.transparent : (isActive ? Colors.transparent : sc.border),
                                ),
                              ),
                              child: Text(
                                '$opt',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: fgColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
    _isWarningOpen = false;
  }

  Future<void> _showSortDialog() async {
    final sc = context.snapgroveColors;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sc.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sc.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sort by',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _SortOption(label: 'Date Created', isActive: true, onTap: () => Navigator.of(ctx).pop()),
                _SortOption(label: 'Date Modified', isActive: false, onTap: () => Navigator.of(ctx).pop()),
                _SortOption(label: 'Name', isActive: false, onTap: () => Navigator.of(ctx).pop()),
                _SortOption(label: 'Size', isActive: false, onTap: () => Navigator.of(ctx).pop()),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: sc.border, height: 1),
                ),
                const Text(
                  'Order by',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _SortOption(label: 'Ascending', isActive: false, onTap: () => Navigator.of(ctx).pop()),
                _SortOption(label: 'Descending', isActive: true, onTap: () => Navigator.of(ctx).pop()),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
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
    if (result == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final width = MediaQuery.of(context).size.width;
    if (_lastWidth != width && !_isWarningOpen) {
      _lastWidth = width;
      _checkResizeWarning(width);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitConfirmation(context);
      },
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          final isLoading = _viewModel.isLoading || _isTransitioning;
          
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              cacheExtent: 1500, // Increased cache for even smoother scrolling
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
                    onPressed: () => _showExitConfirmation(context),
                  ),
                  actions: [
                    if (!isLoading && _viewModel.files.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _IconSquare(
                              svgPath: 'assets/icons/sort.svg',
                              onTap: _showSortDialog,
                            ),
                            const SizedBox(width: 10),
                            _IconSquare(
                              svgPath: 'assets/icons/grid.svg',
                              onTap: () => _showViewDialog(width),
                            ),
                            const SizedBox(width: 10),
                            _IconSquare(
                              svgPath: 'assets/icons/palette.svg',
                              onTap: () {
                                final appVM = locator<AppViewModel>();
                                showGeneralDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  barrierLabel: 'Dismiss',
                                  barrierColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                                  transitionDuration: const Duration(milliseconds: 250),
                                  pageBuilder: (ctx, anim1, anim2) => ThemeDialog(
                                    currentTheme: appVM.themeMode,
                                    onThemeChanged: appVM.setThemeMode,
                                  ),
                                  transitionBuilder: (ctx, anim1, anim2, child) {
                                    final curve = Curves.easeOutBack.transform(anim1.value);
                                    return Transform.scale(
                                      scale: 0.9 + (0.1 * curve),
                                      child: Opacity(opacity: anim1.value, child: child),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _currentColumns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const SkeletonLoader(),
                        childCount: _currentColumns * 3, // Render a few rows of skeletons
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _currentColumns,
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
                            files: _viewModel.files,
                            initialIndex: index,
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
    
    // For both Windows and Android (SAF), use ThumbnailManager for high performance
    if (Platform.isWindows || path.startsWith('content://')) {
      return FutureBuilder<Uint8List?>(
        key: ValueKey('native_$path'),
        future: _thumbnailManager.getThumbnail(path),
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

class _IconSquare extends StatelessWidget {
  final String svgPath;
  final VoidCallback onTap;

  const _IconSquare({required this.svgPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: sc.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: sc.menuHover,
          splashColor: sc.rippleColor,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SvgPicture.asset(
              svgPath,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white : Colors.black,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SortOption({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isActive 
        ? (isDark ? Colors.white : Colors.black)
        : sc.surfaceMuted;
    final fgColor = isActive
        ? (isDark ? Colors.black : Colors.white)
        : sc.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? Colors.transparent : sc.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: fgColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final String path;
  final Widget Function() buildImage;
  final List<String> files;
  final int initialIndex;

  const _GalleryItem({
    required this.path, 
    required this.buildImage,
    required this.files,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImagePreviewView(
              files: files,
              initialIndex: initialIndex,
            ),
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
