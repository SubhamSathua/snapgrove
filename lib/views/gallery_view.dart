import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/locator.dart';
import '../viewmodels/gallery_view_model.dart';
import '../viewmodels/app_view_model.dart';
import '../theme/app_theme.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../services/web_image_utils.dart';
import '../services/thumbnail_manager.dart';
import 'image_preview_view.dart';
import 'theme_dialog.dart';

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
  final ScrollController _scrollController = ScrollController();

  // Ambience generation from visible images
  final Map<String, Color> _imageColorCache = {};
  Color _ambientTopColor = const Color(0xFFf89838);
  Color _ambientBottomColor = const Color(0xFFf89838);
  bool _isExtractingAmbience = false;

  // Grid Configuration
  int? _userSelectedColumns;

  // Selection Mode
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = <int>{};

  @override
  void initState() {
    super.initState();
    _viewModel = locator<GalleryViewModel>(param1: widget.path);

    _loadGridPreference();

    _scrollController.addListener(_handleGalleryScroll);

    // Delay loading until transition finishes for smoother entrance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _isTransitioning = false);
          _viewModel.loadFiles().then((_) {
            if (mounted) {
              _handleGalleryScroll();
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleGalleryScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleGalleryScroll() {
    if (!mounted) return;
    final width = MediaQuery.maybeOf(context)?.size.width ?? 1000.0;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isDesktop = !isAndroid && width >= 720;
    final useSidePane = _isSelectionMode && isDesktop;
    final effectiveColumns = _getEffectiveColumns(width, isRightPaneOpen: useSidePane);
    final gridWidth = useSidePane ? width - 280 : width;
    _updateAmbienceFromVisibleImages(gridWidth, effectiveColumns);
  }

  void _updateAmbienceFromVisibleImages(double width, int effectiveColumns) {
    if (!mounted || _viewModel.files.isEmpty) return;

    final files = _viewModel.files;
    final int count = files.length;

    int firstVisible = 0;
    int lastVisible = (effectiveColumns * 3).clamp(0, count - 1);

    if (_scrollController.hasClients && _scrollController.position.hasViewportDimension) {
      final offset = _scrollController.offset.clamp(0.0, _scrollController.position.maxScrollExtent);
      final viewportHeight = _scrollController.position.viewportDimension;
      final gridWidth = width - 20; // 10 horizontal padding on each side
      final itemWidth = (gridWidth - (effectiveColumns - 1) * 6) / effectiveColumns;
      final rowHeight = itemWidth + 6;

      if (rowHeight > 0) {
        final firstRow = (offset / rowHeight).floor().clamp(0, (count / effectiveColumns).ceil());
        final lastRow = ((offset + viewportHeight) / rowHeight).ceil().clamp(0, (count / effectiveColumns).ceil());

        firstVisible = (firstRow * effectiveColumns).clamp(0, count - 1);
        lastVisible = ((lastRow + 1) * effectiveColumns - 1).clamp(0, count - 1);
      }
    }

    if (firstVisible > lastVisible) {
      final temp = firstVisible;
      firstVisible = lastVisible;
      lastVisible = temp;
    }

    final visiblePaths = <String>[];
    for (int i = firstVisible; i <= lastVisible && i < count; i++) {
      visiblePaths.add(files[i]);
    }

    if (visiblePaths.isEmpty) return;

    final uncached = visiblePaths.where((p) => !_imageColorCache.containsKey(p)).toList();
    if (uncached.isNotEmpty && !_isExtractingAmbience) {
      _isExtractingAmbience = true;
      Future.microtask(() async {
        for (final p in uncached) {
          await _extractImageColor(p);
        }
        if (mounted) {
          _isExtractingAmbience = false;
          _computeAmbientGradient(visiblePaths);
        }
      });
    }

    _computeAmbientGradient(visiblePaths);
  }

  void _computeAmbientGradient(List<String> visiblePaths) {
    if (visiblePaths.isEmpty) return;

    final mid = (visiblePaths.length / 2).ceil();
    final topHalf = visiblePaths.sublist(0, mid);
    final bottomHalf = visiblePaths.sublist(mid > 0 && mid < visiblePaths.length ? mid : 0);

    final topColors = topHalf.map((p) => _imageColorCache[p]).whereType<Color>().toList();
    final bottomColors = bottomHalf.map((p) => _imageColorCache[p]).whereType<Color>().toList();

    Color newTop = _ambientTopColor;
    Color newBottom = _ambientBottomColor;

    if (topColors.isNotEmpty) {
      newTop = _blendColors(topColors);
    }
    if (bottomColors.isNotEmpty) {
      newBottom = _blendColors(bottomColors);
    } else if (topColors.isNotEmpty) {
      newBottom = newTop;
    }

    if (newTop != _ambientTopColor || newBottom != _ambientBottomColor) {
      setState(() {
        _ambientTopColor = newTop;
        _ambientBottomColor = newBottom;
      });
    }
  }

  Color _blendColors(List<Color> colors) {
    if (colors.isEmpty) return const Color(0xFFf89838);
    int r = 0, g = 0, b = 0;
    for (final c in colors) {
      r += (c.r * 255.0).round();
      g += (c.g * 255.0).round();
      b += (c.b * 255.0).round();
    }
    return Color.fromARGB(
      255,
      (r ~/ colors.length).clamp(0, 255),
      (g ~/ colors.length).clamp(0, 255),
      (b ~/ colors.length).clamp(0, 255),
    );
  }

  Future<Color> _extractImageColor(String path) async {
    if (_imageColorCache.containsKey(path)) {
      return _imageColorCache[path]!;
    }

    try {
      Uint8List? bytes;
      if (!kIsWeb) {
        bytes = await _thumbnailManager.getThumbnail(path);
        bytes ??= await locator<FileService>().readFile(path);
      }

      if (bytes != null && bytes.isNotEmpty) {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 16,
          targetHeight: 16,
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();

        if (byteData != null) {
          int rSum = 0;
          int gSum = 0;
          int bSum = 0;
          int count = 0;
          final len = byteData.lengthInBytes;

          for (int i = 0; i < len; i += 4) {
            final r = byteData.getUint8(i);
            final g = byteData.getUint8(i + 1);
            final b = byteData.getUint8(i + 2);
            final a = byteData.getUint8(i + 3);

            if (a > 50) {
              final maxC = [r, g, b].reduce((curr, next) => curr > next ? curr : next);
              final minC = [r, g, b].reduce((curr, next) => curr < next ? curr : next);
              final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
              final weight = 1 + (sat * 3).toInt();

              rSum += r * weight;
              gSum += g * weight;
              bSum += b * weight;
              count += weight;
            }
          }

          if (count > 0) {
            final color = Color.fromARGB(
              255,
              (rSum ~/ count).clamp(0, 255),
              (gSum ~/ count).clamp(0, 255),
              (bSum ~/ count).clamp(0, 255),
            );
            _imageColorCache[path] = color;
            return color;
          }
        }
      }
    } catch (_) {}

    const fallback = Color(0xFFf89838);
    _imageColorCache[path] = fallback;
    return fallback;
  }

  Future<void> _loadGridPreference() async {
    try {
      final storage = locator<StorageService>();
      final savedCols = await storage.read('settings', 'grid_columns');
      if (savedCols is int && mounted) {
        setState(() => _userSelectedColumns = savedCols);
      }
    } catch (_) {}
  }



  void _enterSelectionMode({int? initialIndex}) {
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.clear();
      if (initialIndex != null) {
        _selectedIndices.add(initialIndex);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.clear();
      _selectedIndices.addAll(List.generate(_viewModel.files.length, (i) => i));
    });
  }

  void _unselectAll() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  Future<void> _showContextMenu(BuildContext context, Offset position, int index) async {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final relativeRect = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: relativeRect,
      color: sc.surfaceElevated,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: sc.border),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'select',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.checklist, size: 18, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 10),
              Text(
                'Select',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'select_all',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.select_all, size: 18, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 10),
              Text(
                'Select All',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'preview',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.preview, size: 18, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 10),
              Text(
                'Preview',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!context.mounted || selected == null) return;
    switch (selected) {
      case 'select':
        _enterSelectionMode(initialIndex: index);
        break;
      case 'select_all':
        _selectAll();
        break;
      case 'preview':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImagePreviewView(
              files: _viewModel.files,
              initialIndex: index,
            ),
          ),
        );
        break;
    }
  }

  int _getMaxAllowedColumns(double width) {
    if (width < 380) return 3;
    if (width < 600) return 5;
    if (width < 900) return 7;
    if (width < 1400) return 10;
    return 12;
  }

  int _getEffectiveColumns(double width, {bool isRightPaneOpen = false}) {
    if (isRightPaneOpen) {
      return 5;
    }
    final isMobile = width < 600;
    final defaultCols = isMobile ? 3 : 7;
    final maxAllowed = _getMaxAllowedColumns(width);
    final userPref = _userSelectedColumns ?? defaultCols;
    return userPref.clamp(isMobile ? 2 : 3, maxAllowed);
  }

  Future<void> _showViewDialog(double width) async {
    final sc = context.snapgroveColors;
    final isMobile = width < 600;
    final List<int> options = isMobile ? [2, 3, 4, 5] : [3, 4, 5, 6, 7, 10, 12];
    final maxAllowed = _getMaxAllowedColumns(width);
    final currentEffective = _getEffectiveColumns(width);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
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
                    const Text(
                      'Grid Layout',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose the number of columns',
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
                        final isActive = currentEffective == opt;
                        
                        final bgColor = isActive 
                            ? (isDark ? Colors.white : Colors.black)
                            : sc.surfaceMuted;
                        final fgColor = isActive
                            ? (isDark ? Colors.black : Colors.white)
                            : sc.muted;

                        return InkWell(
                          onTap: isDisabled ? null : () {
                            setState(() => _userSelectedColumns = opt);
                            locator<StorageService>().write('settings', 'grid_columns', opt);
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
  }

  String _getDisplayFolderName(String path, String fallbackTitle) {
    if (path.isEmpty) {
      if (fallbackTitle.isNotEmpty &&
          fallbackTitle != 'Browse Gallery' &&
          fallbackTitle != 'Screenshot Folder' &&
          fallbackTitle != 'Organizer Gallery') {
        return fallbackTitle;
      }
      return 'Gallery';
    }

    // Android SAF Content URI (e.g. content://.../tree/primary%3APictures%2FScreenshots)
    if (path.startsWith('content://')) {
      try {
        final decoded = Uri.decodeFull(path);
        final lastSlash = decoded.lastIndexOf('/');
        final lastColon = decoded.lastIndexOf(':');
        String name = decoded;
        if (lastSlash != -1 || lastColon != -1) {
          final splitPoint = lastColon > lastSlash ? lastColon : lastSlash;
          name = decoded.substring(splitPoint + 1);
        }
        name = name.trim();
        if (name.isNotEmpty && name != 'tree' && name != 'document') {
          return name;
        }
      } catch (_) {}
    }

    // Standard local filesystem path (Windows, Linux, macOS, iOS) or Web directory name
    try {
      String cleanPath = path.replaceAll(r'\', '/');
      while (cleanPath.endsWith('/')) {
        cleanPath = cleanPath.substring(0, cleanPath.length - 1);
      }
      final lastSlash = cleanPath.lastIndexOf('/');
      final name = lastSlash != -1 ? cleanPath.substring(lastSlash + 1) : cleanPath;
      if (name.trim().isNotEmpty && name != '/' && name != '\\') {
        return name.trim();
      }
    } catch (_) {}

    return 'Gallery';
  }

  Future<void> _showSortDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final sc = context.snapgroveColors;
          final currentField = _viewModel.sortField;
          final currentOrder = _viewModel.sortOrder;

          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 310,
                padding: const EdgeInsets.all(22),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        _GroupedOptionTile(
                          label: 'Date Modified',
                          isActive: currentField == SortField.dateModified,
                          isFirst: true,
                          isLast: false,
                          onTap: () {
                            setStateDialog(() {});
                            _viewModel.setSort(SortField.dateModified, currentOrder);
                          },
                        ),
                        const SizedBox(height: 2),
                        _GroupedOptionTile(
                          label: 'Name',
                          isActive: currentField == SortField.name,
                          isFirst: false,
                          isLast: false,
                          onTap: () {
                            setStateDialog(() {});
                            _viewModel.setSort(SortField.name, currentOrder);
                          },
                        ),
                        const SizedBox(height: 2),
                        _GroupedOptionTile(
                          label: 'File Size',
                          isActive: currentField == SortField.size,
                          isFirst: false,
                          isLast: true,
                          onTap: () {
                            setStateDialog(() {});
                            _viewModel.setSort(SortField.size, currentOrder);
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: sc.border, height: 1),
                    ),
                    const Text(
                      'Order by',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        _GroupedOptionTile(
                          label: 'Ascending',
                          isActive: currentOrder == SortOrder.ascending,
                          isFirst: true,
                          isLast: false,
                          onTap: () {
                            setStateDialog(() {});
                            _viewModel.setSort(currentField, SortOrder.ascending);
                          },
                        ),
                        const SizedBox(height: 2),
                        _GroupedOptionTile(
                          label: 'Descending',
                          isActive: currentOrder == SortOrder.descending,
                          isFirst: false,
                          isLast: true,
                          onTap: () {
                            setStateDialog(() {});
                            _viewModel.setSort(currentField, SortOrder.descending);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

  Future<void> _confirmExitSelectionMode(BuildContext context) async {
    if (_selectedIndices.isEmpty) {
      _exitSelectionMode();
      return;
    }

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
                  'Discard selection?',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your current selection of ${_selectedIndices.length} item(s) will be lost.',
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sc.accent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text(
                          'Stay',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: sc.muted,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Discard',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
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

    if (result == true && mounted) {
      _exitSelectionMode();
    }
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sc.accent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text(
                          'Stay',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: sc.muted,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Quit',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
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
    final width = MediaQuery.of(context).size.width;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isDesktop = !isAndroid && width >= 720;
    final useSidePane = _isSelectionMode && isDesktop;
    final useTopPane = _isSelectionMode && !isDesktop;
    final effectiveColumns = _getEffectiveColumns(width, isRightPaneOpen: useSidePane);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          if (_isSelectionMode) {
            _confirmExitSelectionMode(context);
            return KeyEventResult.handled;
          } else {
            _showExitConfirmation(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_isSelectionMode) {
            await _confirmExitSelectionMode(context);
          } else {
            await _showExitConfirmation(context);
          }
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([_viewModel, locator<AppViewModel>()]),
          builder: (context, child) {
            final isLoading = _viewModel.isLoading || _isTransitioning;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sc = context.snapgroveColors;
            
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: useSidePane
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildGalleryScrollView(
                            context: context,
                            width: width - 280,
                            effectiveColumns: effectiveColumns,
                            isLoading: isLoading,
                            isDark: isDark,
                            sc: sc,
                            useTopPane: false,
                          ),
                        ),
                        _RightSideSelectionPane(
                          selectedCount: _selectedIndices.length,
                          subfolders: _viewModel.subfolders,
                          onCreateFolder: _showCreateFolderDialog,
                          onMoveToFolder: _moveSelectedToFolder,
                          topAmbientColor: _ambientTopColor,
                          bottomAmbientColor: _ambientBottomColor,
                        ),
                      ],
                    )
                  : _buildGalleryScrollView(
                      context: context,
                      width: width,
                      effectiveColumns: effectiveColumns,
                      isLoading: isLoading,
                      isDark: isDark,
                      sc: sc,
                      useTopPane: useTopPane,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGalleryScrollView({
    required BuildContext context,
    required double width,
    required int effectiveColumns,
    required bool isLoading,
    required bool isDark,
    required SnapgroveColors sc,
    required bool useTopPane,
  }) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      scrollCacheExtent: const ScrollCacheExtent.pixels(1500),
      slivers: [
        SliverAppBar(
          expandedHeight: _isSelectionMode ? kToolbarHeight : ((width < 400) ? 128.0 : 120.0),
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
            onPressed: () => _isSelectionMode ? _confirmExitSelectionMode(context) : _showExitConfirmation(context),
          ),
          actions: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (width >= 720) ...[
                      _SelectAllButton(
                        isAllSelected: _viewModel.files.isNotEmpty && _selectedIndices.length == _viewModel.files.length,
                        onTap: (_viewModel.files.isNotEmpty && _selectedIndices.length == _viewModel.files.length)
                            ? _unselectAll
                            : _selectAll,
                      ),
                      const SizedBox(width: 10),
                      _IconSquare(
                        svgPath: 'assets/icons/Back-Btn.svg',
                        onTap: () => _confirmExitSelectionMode(context),
                      ),
                    ] else ...[
                      PopupMenuButton<String>(
                        icon: SvgPicture.asset(
                          'assets/icons/more.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            isDark ? Colors.white : Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                        color: sc.surfaceElevated,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: sc.border),
                        ),
                        onSelected: (val) {
                          if (val == 'toggle_select_all') {
                            if (_viewModel.files.isNotEmpty && _selectedIndices.length == _viewModel.files.length) {
                              _unselectAll();
                            } else {
                              _selectAll();
                            }
                          } else if (val == 'exit') {
                            _confirmExitSelectionMode(context);
                          }
                        },
                        itemBuilder: (context) {
                          final isAll = _viewModel.files.isNotEmpty && _selectedIndices.length == _viewModel.files.length;
                          return [
                            PopupMenuItem(
                              value: 'toggle_select_all',
                              child: Row(
                                children: [
                                  Icon(
                                    isAll ? Icons.deselect : Icons.done_all,
                                    size: 18,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isAll ? 'Unselect All' : 'Select All',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem(
                              value: 'exit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.close,
                                    size: 18,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Exit Selection',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                      const SizedBox(width: 6),
                      _IconSquare(
                        svgPath: 'assets/icons/Back-Btn.svg',
                        onTap: () => _confirmExitSelectionMode(context),
                      ),
                    ],
                  ],
                ),
              )
            else if (!isLoading && _viewModel.files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Select images',
                      child: _IconSquare(
                        icon: Icons.done_all,
                        onTap: () => _enterSelectionMode(),
                      ),
                    ),
                    const SizedBox(width: 10),
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
            title: !_isSelectionMode
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final folderName = _getDisplayFolderName(widget.path, widget.title);
                      final double fontSize = width < 380
                          ? (folderName.length > 14 ? 13.0 : 15.0)
                          : (width < 600 ? (folderName.length > 20 ? 14.0 : 16.0) : 18.0);
                      final double rightPad = !isLoading && _viewModel.files.isNotEmpty
                          ? (width < 600 ? 190.0 : 210.0)
                          : 48.0;

                      return Padding(
                        padding: EdgeInsets.only(left: 56, right: rightPad, bottom: 16),
                        child: Text(
                          folderName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    },
                  )
                : null,
            centerTitle: false,
            titlePadding: EdgeInsets.zero,
          ),
        ),
        if (useTopPane)
          SliverPersistentHeader(
            pinned: true,
            delegate: _TopSelectionPaneDelegate(
              selectedCount: _selectedIndices.length,
              subfolders: _viewModel.subfolders,
              onCreateFolder: _showCreateFolderDialog,
              onMoveToFolder: _moveSelectedToFolder,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              borderColor: sc.border,
              textColor: isDark ? Colors.white : Colors.black,
              mutedColor: sc.muted,
              accentColor: sc.accent,
            ),
          ),
        if (isLoading && _viewModel.files.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: effectiveColumns,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const SkeletonLoader(),
                childCount: effectiveColumns * 3, // Render a few rows of skeletons
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: effectiveColumns,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final path = _viewModel.files[index];
                  return _GalleryItem(
                    path: path,
                    buildImage: () => _buildImage(context, path),
                    files: _viewModel.files,
                    initialIndex: index,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedIndices.contains(index),
                    onSelectionTap: () => _toggleSelection(index),
                    onLongPress: () => _enterSelectionMode(initialIndex: index),
                    onRightClick: (position) => _showContextMenu(context, position, index),
                  );
                },
                childCount: _viewModel.files.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          ),
      ],
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
              width: double.infinity,
              height: double.infinity,
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
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 350,
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
                    width: double.infinity,
                    height: double.infinity,
                    cacheWidth: 350,
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
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 350,
      errorBuilder: (context, error, stackTrace) => _ErrorPlaceholder(),
    );
  }

  // Show dialog to create a new folder
  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final sc = context.snapgroveColors;

    final result = await showGeneralDialog<String>(
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
                const Text(
                  'Create New Folder',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Folder name',
                    hintStyle: TextStyle(fontFamily: 'Lora', color: sc.muted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: sc.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: sc.accent),
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'Lora'),
                  onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Cancel', style: TextStyle(color: sc.muted)),
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
                        onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                        child: const Text('Create'),
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
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final success = await _viewModel.createSubfolder(result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "$result" created'), behavior: SnackBarBehavior.floating),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to create folder'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // Move selected files to the specified folder
  Future<void> _moveSelectedToFolder(String folderName) async {
    final selectedFiles = _selectedIndices.map((i) => _viewModel.files[i]).toList();
    if (selectedFiles.isEmpty) return;

    final success = await _viewModel.moveFilesToFolder(selectedFiles, folderName);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved ${selectedFiles.length} files to $folderName'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _exitSelectionMode();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Failed to move files'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _IconSquare extends StatelessWidget {
  final String? svgPath;
  final IconData? icon;
  final VoidCallback onTap;

  const _IconSquare({this.svgPath, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : Colors.black;

    Widget childWidget;
    if (icon != null) {
      childWidget = Icon(icon, size: 20, color: fgColor);
    } else if (svgPath != null) {
      childWidget = SvgPicture.asset(
        svgPath!,
        colorFilter: ColorFilter.mode(
          fgColor,
          BlendMode.srcIn,
        ),
      );
    } else {
      childWidget = const SizedBox.shrink();
    }

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
            child: Center(child: childWidget),
          ),
        ),
      ),
    );
  }
}

class _GroupedOptionTile extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _GroupedOptionTile({
    required this.label,
    required this.isActive,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const double outerRadius = 10.0;
    const double innerRadius = 3.5;

    final BorderRadius borderRadius;
    if (isFirst && isLast) {
      borderRadius = BorderRadius.circular(outerRadius);
    } else if (isFirst) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(outerRadius),
        topRight: Radius.circular(outerRadius),
        bottomLeft: Radius.circular(innerRadius),
        bottomRight: Radius.circular(innerRadius),
      );
    } else if (isLast) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(innerRadius),
        topRight: Radius.circular(innerRadius),
        bottomLeft: Radius.circular(outerRadius),
        bottomRight: Radius.circular(outerRadius),
      );
    } else {
      borderRadius = BorderRadius.circular(innerRadius);
    }

    final bgColor = isActive
        ? (isDark ? Colors.white : Colors.black)
        : sc.surfaceMuted;
    final fgColor = isActive
        ? (isDark ? Colors.black : Colors.white)
        : sc.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: sc.menuHover,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
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
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onLongPress;
  final void Function(Offset)? onRightClick;

  const _GalleryItem({
    required this.path, 
    required this.buildImage,
    required this.files,
    required this.initialIndex,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionTap,
    this.onLongPress,
    this.onRightClick,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final bool activeSelection = isSelectionMode && isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isSelectionMode) {
            onSelectionTap?.call();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImagePreviewView(
                  files: files,
                  initialIndex: initialIndex,
                ),
              ),
            );
          }
        },
        onLongPress: onLongPress,
        onSecondaryTapUp: onRightClick != null
            ? (details) => onRightClick!(details.globalPosition)
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: sc.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: activeSelection ? sc.accent : sc.border,
              width: activeSelection ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(activeSelection ? 5.5 : 7.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                buildImage(),
                if (activeSelection)
                  Container(
                    color: sc.accent.withValues(alpha: 0.25),
                  ),
                if (activeSelection)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.done_all,
                      size: 22,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSelectionPaneDelegate extends SliverPersistentHeaderDelegate {
  final int selectedCount;
  final List<String> subfolders;
  final VoidCallback onCreateFolder;
  final void Function(String) onMoveToFolder;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final Color accentColor;

  _TopSelectionPaneDelegate({
    required this.selectedCount,
    required this.subfolders,
    required this.onCreateFolder,
    required this.onMoveToFolder,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.accentColor,
  });

  double get _height => subfolders.isNotEmpty ? 92.0 : 48.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: 0.70),
            border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.85))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '$selectedCount selected',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  _CreateFolderButton(
                    onTap: onCreateFolder,
                    fullWidth: false,
                  ),
                ],
              ),
              if (subfolders.isNotEmpty) ...[
                const SizedBox(height: 8),
                _HorizontalChipsBar(
                  subfolders: subfolders,
                  onMoveToFolder: onMoveToFolder,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TopSelectionPaneDelegate oldDelegate) {
    return oldDelegate.selectedCount != selectedCount ||
        oldDelegate.subfolders != subfolders ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class _HorizontalChipsBar extends StatefulWidget {
  final List<String> subfolders;
  final void Function(String) onMoveToFolder;

  const _HorizontalChipsBar({
    required this.subfolders,
    required this.onMoveToFolder,
  });

  @override
  State<_HorizontalChipsBar> createState() => _HorizontalChipsBarState();
}

class _HorizontalChipsBarState extends State<_HorizontalChipsBar> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void didUpdateWidget(covariant _HorizontalChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final canLeft = current > 4;
    final canRight = (maxScroll - current) > 4;

    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canLeft;
          _canScrollRight = canRight;
        });
      }
    }
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(
              left: _canScrollLeft ? 32 : 2,
              right: _canScrollRight ? 32 : 2,
            ),
            itemCount: widget.subfolders.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final folder = widget.subfolders[index];
              return _ActionChip(
                label: folder,
                onTap: () => widget.onMoveToFolder(folder),
              );
            },
          ),
          if (_canScrollLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      bgColor.withValues(alpha: 0.70),
                      bgColor.withValues(alpha: 0.65),
                      bgColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.only(right: 6),
                child: Center(
                  child: InkWell(
                    onTap: () => _scroll(-140),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: sc.surfaceElevated.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: sc.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_canScrollRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      bgColor.withValues(alpha: 0.0),
                      bgColor.withValues(alpha: 0.65),
                      bgColor.withValues(alpha: 0.70),
                    ],
                  ),
                ),
                padding: const EdgeInsets.only(left: 6),
                child: Center(
                  child: InkWell(
                    onTap: () => _scroll(140),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: sc.surfaceElevated.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: sc.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RightSideSelectionPane extends StatelessWidget {
  final int selectedCount;
  final List<String> subfolders;
  final VoidCallback onCreateFolder;
  final void Function(String) onMoveToFolder;
  final Color topAmbientColor;
  final Color bottomAmbientColor;

  const _RightSideSelectionPane({
    required this.selectedCount,
    required this.subfolders,
    required this.onCreateFolder,
    required this.onMoveToFolder,
    this.topAmbientColor = const Color(0xFFf89838),
    this.bottomAmbientColor = const Color(0xFFf89838),
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: 280,
          decoration: BoxDecoration(
            color: (isDark ? sc.surfaceElevated : Colors.white).withValues(alpha: 0.70),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      Color.alphaBlend(
                        topAmbientColor.withValues(alpha: 0.20),
                        sc.surfaceElevated.withValues(alpha: 0.70),
                      ),
                      sc.surfaceElevated.withValues(alpha: 0.70),
                      Color.alphaBlend(
                        bottomAmbientColor.withValues(alpha: 0.16),
                        sc.surfaceElevated.withValues(alpha: 0.70),
                      ),
                    ]
                  : [
                      Color.alphaBlend(
                        topAmbientColor.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.70),
                      ),
                      Colors.white.withValues(alpha: 0.70),
                      Color.alphaBlend(
                        bottomAmbientColor.withValues(alpha: 0.14),
                        sc.surfaceMuted.withValues(alpha: 0.70),
                      ),
                    ],
            ),
            border: Border(left: BorderSide(color: sc.border.withValues(alpha: 0.85))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header (total selected, create folder at top)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$selectedCount selected',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CreateFolderButton(
                      onTap: onCreateFolder,
                      fullWidth: true,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: sc.border.withValues(alpha: 0.75)),
              // Subfolders / Tags (2 per row with vertical scroll if overflow)
              Expanded(
                child: subfolders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder_open_outlined, size: 36, color: sc.muted.withValues(alpha: 0.5)),
                              const SizedBox(height: 8),
                              Text(
                                'No subfolders.\nCreate a folder to move files.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Lora',
                                  fontSize: 13,
                                  color: sc.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.6,
                          ),
                          itemCount: subfolders.length,
                          itemBuilder: (context, index) {
                            final folder = subfolders[index];
                            return _ActionChip(
                              label: folder,
                              onTap: () => onMoveToFolder(folder),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateFolderButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool fullWidth;

  const _CreateFolderButton({
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  State<_CreateFolderButton> createState() => _CreateFolderButtonState();
}

class _CreateFolderButtonState extends State<_CreateFolderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const Color defaultBg = Color(0xFFf89838);
    const Color hoverBg = Color(0xFFe68524);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: widget.fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: _isHovered ? hoverBg : defaultBg,
          borderRadius: BorderRadius.circular(6),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFFf89838).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(6),
            splashColor: Colors.black.withValues(alpha: 0.15),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.create_new_folder, size: 16, color: Color(0xFF000000)),
                  SizedBox(width: 8),
                  Text(
                    'Create Folder',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF000000),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectAllButton extends StatefulWidget {
  final bool isAllSelected;
  final VoidCallback onTap;

  const _SelectAllButton({
    required this.isAllSelected,
    required this.onTap,
  });

  @override
  State<_SelectAllButton> createState() => _SelectAllButtonState();
}

class _SelectAllButtonState extends State<_SelectAllButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _isHovered ? sc.menuHover : sc.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sc.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: sc.rippleColor,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isAllSelected ? Icons.deselect : Icons.done_all,
                    size: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isAllSelected ? 'Unselect All' : 'Select All',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color defaultBg = isDark ? const Color(0xFF1a1a1a).withValues(alpha: 0.75) : const Color(0xFFf3f3f3).withValues(alpha: 0.75);
    final Color hoverBg = isDark ? const Color(0xFF282828).withValues(alpha: 0.85) : const Color(0xFFe5e5e5).withValues(alpha: 0.85);
    final Color defaultBorder = isDark ? const Color(0xFF2f2f2f) : const Color(0xFFd7d7d7);
    final Color hoverBorder = isDark ? const Color(0xFF4a4a4a) : const Color(0xFFb5b5b5);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          splashColor: const Color(0xFFf89838).withValues(alpha: 0.25),
          hoverColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isHovered ? hoverBg : defaultBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isHovered ? hoverBorder : defaultBorder,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
