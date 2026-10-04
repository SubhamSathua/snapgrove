import 'dart:async';
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
import '../services/notification_service.dart';
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

  // Ambience generation from visible images (3 colors per image, natural saturation)
  final Map<String, List<Color>> _imageColorPaletteMap = {};
  Color _ambientTopColor = const Color(0xFFf89838);
  Color _ambientMidColor = const Color(0xFFf89838);
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

  Timer? _ambienceDebounceTimer;

  @override
  void dispose() {
    _ambienceDebounceTimer?.cancel();
    _scrollController.removeListener(_handleGalleryScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleGalleryScroll() {
    if (!mounted) return;
    _ambienceDebounceTimer?.cancel();
    _ambienceDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      final width = MediaQuery.maybeOf(context)?.size.width ?? 1000.0;
      final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final isDesktop = !isAndroid && width >= 720;
      final useSidePane = _isSelectionMode && isDesktop;
      final effectiveColumns = _getEffectiveColumns(width, isRightPaneOpen: useSidePane);
      final gridWidth = useSidePane ? width - 280 : width;
      _updateAmbienceFromVisibleImages(gridWidth, effectiveColumns);
    });
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

    final uncached = visiblePaths.where((p) => !_imageColorPaletteMap.containsKey(p)).toList();
    if (uncached.isNotEmpty && !_isExtractingAmbience) {
      _isExtractingAmbience = true;
      Future.microtask(() async {
        for (final p in uncached) {
          await _extractImagePalette(p);
        }
        if (mounted) {
          _isExtractingAmbience = false;
          _computeAmbientPalette(visiblePaths);
        }
      });
    }

    _computeAmbientPalette(visiblePaths);
  }

  void _computeAmbientPalette(List<String> visiblePaths) {
    if (visiblePaths.isEmpty) return;

    final topColors = <Color>[];
    final midColors = <Color>[];
    final bottomColors = <Color>[];

    final total = visiblePaths.length;
    for (int i = 0; i < total; i++) {
      final palette = _imageColorPaletteMap[visiblePaths[i]];
      if (palette != null && palette.length >= 3) {
        if (i < (total * 0.4).ceil()) {
          topColors.add(palette[0]);
          midColors.add(palette[1]);
        } else if (i < (total * 0.7).ceil()) {
          midColors.add(palette[1]);
          bottomColors.add(palette[2]);
        } else {
          bottomColors.add(palette[2]);
          midColors.add(palette[1]);
        }
      }
    }

    Color newTop = topColors.isNotEmpty ? _blendNaturalColors(topColors) : _ambientTopColor;
    Color newMid = midColors.isNotEmpty ? _blendNaturalColors(midColors) : _ambientMidColor;
    Color newBottom = bottomColors.isNotEmpty ? _blendNaturalColors(bottomColors) : _ambientBottomColor;

    if (newTop != _ambientTopColor || newMid != _ambientMidColor || newBottom != _ambientBottomColor) {
      setState(() {
        _ambientTopColor = newTop;
        _ambientMidColor = newMid;
        _ambientBottomColor = newBottom;
      });
    }
  }

  Color _blendNaturalColors(List<Color> colors) {
    if (colors.isEmpty) return const Color(0xFFf89838);
    int r = 0, g = 0, b = 0;
    for (final c in colors) {
      r += (c.r * 255.0).round();
      g += (c.g * 255.0).round();
      b += (c.b * 255.0).round();
    }
    final raw = Color.fromARGB(
      255,
      (r ~/ colors.length).clamp(0, 255),
      (g ~/ colors.length).clamp(0, 255),
      (b ~/ colors.length).clamp(0, 255),
    );
    return _normalizeNaturalColor(raw);
  }

  Future<List<Color>> _extractImagePalette(String path) async {
    if (_imageColorPaletteMap.containsKey(path)) {
      return _imageColorPaletteMap[path]!;
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
          int rTop = 0, gTop = 0, bTop = 0, countTop = 0;
          int rMid = 0, gMid = 0, bMid = 0, countMid = 0;
          int rBot = 0, gBot = 0, bBot = 0, countBot = 0;

          for (int y = 0; y < 16; y++) {
            for (int x = 0; x < 16; x++) {
              final idx = (y * 16 + x) * 4;
              final r = byteData.getUint8(idx);
              final g = byteData.getUint8(idx + 1);
              final b = byteData.getUint8(idx + 2);
              final a = byteData.getUint8(idx + 3);

              if (a > 40) {
                final maxC = [r, g, b].reduce((curr, next) => curr > next ? curr : next);
                final minC = [r, g, b].reduce((curr, next) => curr < next ? curr : next);
                final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
                final weight = 1 + (sat * 2).toInt();

                if (y < 6) {
                  rTop += r * weight;
                  gTop += g * weight;
                  bTop += b * weight;
                  countTop += weight;
                } else if (y < 11) {
                  rMid += r * weight;
                  gMid += g * weight;
                  bMid += b * weight;
                  countMid += weight;
                } else {
                  rBot += r * weight;
                  gBot += g * weight;
                  bBot += b * weight;
                  countBot += weight;
                }
              }
            }
          }

          Color topColor = countTop > 0
              ? Color.fromARGB(255, rTop ~/ countTop, gTop ~/ countTop, bTop ~/ countTop)
              : const Color(0xFFf89838);
          Color midColor = countMid > 0
              ? Color.fromARGB(255, rMid ~/ countMid, gMid ~/ countMid, bMid ~/ countMid)
              : topColor;
          Color botColor = countBot > 0
              ? Color.fromARGB(255, rBot ~/ countBot, gBot ~/ countBot, bBot ~/ countBot)
              : midColor;

          topColor = _normalizeNaturalColor(topColor);
          midColor = _normalizeNaturalColor(midColor);
          botColor = _normalizeNaturalColor(botColor);

          final palette = [topColor, midColor, botColor];
          _imageColorPaletteMap[path] = palette;
          return palette;
        }
      }
    } catch (_) {}

    const fallback = [Color(0xFFf89838), Color(0xFFf89838), Color(0xFFf89838)];
    _imageColorPaletteMap[path] = fallback;
    return fallback;
  }

  Color _normalizeNaturalColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    final naturalSat = hsv.saturation.clamp(0.15, 0.85);
    final naturalVal = hsv.value.clamp(0.60, 0.90);
    return hsv.withSaturation(naturalSat).withValue(naturalVal).toColor();
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
              directoryPath: _viewModel.path,
              subfolders: _viewModel.subfolders,
              onFolderCreated: (name) => _viewModel.createSubfolder(name),
              onFileMoved: (file, folder) => _viewModel.moveFilesToFolder([file], folder),
              onFileDeleted: (file) => _viewModel.deleteFilesPermanently([file]),
                            onFileMoveToBin: (file) => _viewModel.moveToBin([file]),
            ),
          ),
        );
        break;
    }
  }

  /// Dynamically computes maximum allowable columns based on viewport width
  int _getMaxAllowedColumns(double width) {
    if (width < 380) return 3;
    if (width < 600) return 5;
    if (width < 900) return 7;
    if (width < 1400) return 10;
    return 12;
  }

  /// Calculates effective columns respecting screen constraints and user preference
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

  Future<void> _showMoreMenuDropdown(BuildContext context, double width) async {
    final sc = context.snapgroveColors;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => StatefulBuilder(
        builder: (context, setStateDropdown) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 54, right: 16),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1 Toggle: Show images from sub-folders (M3 style Switch)
                            InkWell(
                              onTap: () {
                                final nextVal = !_viewModel.includeSubfolders;
                                _viewModel.setIncludeSubfolders(nextVal);
                                setStateDropdown(() {});
                              },
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: sc.menuHover,
                              splashColor: sc.rippleColor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.snippet_folder_outlined,
                                      size: 19,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Show sub-folders',
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.85,
                                      child: Switch(
                                        value: _viewModel.includeSubfolders,
                                        activeThumbColor: sc.accent,
                                        activeTrackColor: sc.accent.withValues(alpha: 0.35),
                                        inactiveThumbColor: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
                                        inactiveTrackColor: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return sc.accent;
                                          }
                                          return isDark ? const Color(0x33FFFFFF) : const Color(0x33000000);
                                        }),
                                        thumbIcon: WidgetStateProperty.resolveWith((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return const Icon(Icons.check, size: 12, color: Colors.black);
                                          }
                                          return null;
                                        }),
                                        onChanged: (val) {
                                          _viewModel.setIncludeSubfolders(val);
                                          setStateDropdown(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: Divider(
                                color: isDark ? const Color(0x1FFFFFFF) : const Color(0x18000000),
                                height: 1,
                              ),
                            ),
                            // Option 1: Grid Layout
                            _DropdownMenuOptionTile(
                              icon: Icons.grid_view_rounded,
                              label: 'Grid Layout',
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _showGridDialog(width);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: Divider(
                                color: isDark ? const Color(0x1FFFFFFF) : const Color(0x18000000),
                                height: 1,
                              ),
                            ),
                            // Option 2: Theme
                            _DropdownMenuOptionTile(
                              icon: Icons.palette_outlined,
                              label: 'Theme',
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _showThemeDialog();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showGridDialog(double width) async {
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 340,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
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
                              onTap: isDisabled
                                  ? null
                                  : () {
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
                                      color: isDisabled
                                          ? Colors.transparent
                                          : (isActive ? Colors.transparent : sc.border),
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

  Future<void> _showThemeDialog() async {
    final appVM = locator<AppViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showGeneralDialog(
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final currentField = _viewModel.sortField;
          final currentOrder = _viewModel.sortOrder;

          return Center(
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 310,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
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
      pageBuilder: (ctx, anim1, anim2) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
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
          ),
        );
      },
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
      pageBuilder: (ctx, anim1, anim2) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
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
    ),
  );
},
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
                          isFolderEnabled: _isFolderActionEnabled,
                          getFolderTooltip: _getFolderActionTooltip,
                          topAmbientColor: _ambientTopColor,
                          midAmbientColor: _ambientMidColor,
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
          leading: Center(
            child: _RoundBackButton(
              onTap: () => _isSelectionMode ? _confirmExitSelectionMode(context) : _showExitConfirmation(context),
            ),
          ),
          actions: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (width >= 720) ...[
                      _SelectionActionButton(
                        icon: Icons.done_all,
                        label: 'Select All',
                        isEnabled: _viewModel.files.isNotEmpty && _selectedIndices.length < _viewModel.files.length,
                        onTap: _selectAll,
                      ),
                      const SizedBox(width: 8),
                      _SelectionActionButton(
                        icon: Icons.deselect,
                        label: 'Unselect',
                        isEnabled: _selectedIndices.isNotEmpty,
                        onTap: _unselectAll,
                      ),
                      const SizedBox(width: 8),
                      _SelectionActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        isEnabled: _selectedIndices.isNotEmpty,
                        onTap: _showDeleteConfirmationDialog,
                      ),
                    ] else ...[
                      IconButton(
                        tooltip: 'Delete selected',
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 22,
                          color: _selectedIndices.isNotEmpty
                              ? (isDark ? Colors.white : Colors.black)
                              : sc.muted.withValues(alpha: 0.4),
                        ),
                        onPressed: _selectedIndices.isNotEmpty ? _showDeleteConfirmationDialog : null,
                      ),
                      const SizedBox(width: 4),
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
                          side: BorderSide(color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                        ),
                        onSelected: (val) {
                          if (val == 'select_all') {
                            _selectAll();
                          } else if (val == 'unselect_all') {
                            _unselectAll();
                          } else if (val == 'delete') {
                            _showDeleteConfirmationDialog();
                          }
                        },
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem(
                              value: 'select_all',
                              enabled: _viewModel.files.isNotEmpty && _selectedIndices.length < _viewModel.files.length,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.done_all,
                                    size: 18,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Select All',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'unselect_all',
                              enabled: _selectedIndices.isNotEmpty,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.deselect,
                                    size: 18,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Unselect All',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedIndices.isNotEmpty) ...[
                              const PopupMenuDivider(height: 1),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Color(0xFFE53935),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Delete',
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 13,
                                        color: Color(0xFFE53935),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ];
                        },
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
                    Tooltip(
                      message: 'Sort',
                      child: _IconSquare(
                        svgPath: 'assets/icons/sort.svg',
                        onTap: _showSortDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Options',
                      child: _IconSquare(
                        icon: Icons.more_vert,
                        onTap: () => _showMoreMenuDropdown(context, width),
                      ),
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
                          ? (width < 600 ? 150.0 : 170.0)
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
              isFolderEnabled: _isFolderActionEnabled,
              getFolderTooltip: _getFolderActionTooltip,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              borderColor: sc.border,
              textColor: isDark ? Colors.white : Colors.black,
              mutedColor: sc.muted,
              accentColor: sc.accent,
              topAmbientColor: _ambientTopColor,
              midAmbientColor: _ambientMidColor,
              bottomAmbientColor: _ambientBottomColor,
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
                  final subfolderTag = _viewModel.getSubfolderTag(path);
                  return _GalleryItem(
                    path: path,
                    subfolderTag: subfolderTag,
                    thumbnailManager: _thumbnailManager,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedIndices.contains(index),
                    onSelectionTap: () => _toggleSelection(index),
                    onOpenPreview: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImagePreviewView(
                            files: _viewModel.files,
                            initialIndex: index,
                            directoryPath: _viewModel.path,
                            subfolders: _viewModel.subfolders,
                            onFolderCreated: (name) => _viewModel.createSubfolder(name),
                            onFileMoved: (file, folder) => _viewModel.moveFilesToFolder([file], folder),
                            onFileDeleted: (file) => _viewModel.deleteFilesPermanently([file]),
                            onFileMoveToBin: (file) => _viewModel.moveToBin([file]),
                          ),
                        ),
                      );
                    },
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
      pageBuilder: (ctx, anim1, anim2) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                              child: const Text(
                                'Create',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: FontWeight.w600,
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
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      locator<NotificationService>().showSnackBar('Folder "$result" created');
      final success = await _viewModel.createSubfolder(result);
      if (!success && mounted) {
        locator<NotificationService>().showSnackBar('Failed to create folder "$result"', isError: true);
      }
    }
  }

  bool _isFolderActionEnabled(String folderName) {
    final selectedFiles = _selectedIndices.map((i) => _viewModel.files[i]).toList();
    if (selectedFiles.isEmpty) return false;
    final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
    if (isMovingToRoot) {
      return selectedFiles.any((f) => _viewModel.getSubfolderTag(f) != null);
    } else {
      return selectedFiles.any((f) {
        final tag = _viewModel.getSubfolderTag(f);
        return tag == null || tag.toLowerCase() != folderName.toLowerCase();
      });
    }
  }

  String? _getFolderActionTooltip(String folderName) {
    final enabled = _isFolderActionEnabled(folderName);
    if (enabled) return null;
    if (folderName == 'ROOT' || folderName.isEmpty) {
      return 'All selected images are already in root';
    }
    return 'All selected images are already in $folderName';
  }

  // Move selected files to the specified folder
  Future<void> _moveSelectedToFolder(String folderName) async {
    final selectedFiles = _selectedIndices.map((i) => _viewModel.files[i]).toList();
    if (selectedFiles.isEmpty) return;

    final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
    final filesToMove = selectedFiles.where((f) {
      final currentTag = _viewModel.getSubfolderTag(f);
      if (isMovingToRoot) {
        return currentTag != null;
      } else {
        return currentTag == null || currentTag.toLowerCase() != folderName.toLowerCase();
      }
    }).toList();

    if (filesToMove.isEmpty) {
      locator<NotificationService>().showSnackBar(
        isMovingToRoot ? 'Selected images are already in root' : 'Selected images are already in $folderName',
      );
      return;
    }

    final count = filesToMove.length;
    final success = await _viewModel.moveFilesToFolder(filesToMove, folderName);
    if (success && mounted) {
      _exitSelectionMode();
      locator<NotificationService>().showSnackBar(
        'Moved $count ${count == 1 ? "file" : "files"} to $folderName',
        actionLabel: 'Undo',
        onAction: () async {
          final undoSuccess = await _viewModel.undoMoveFiles(filesToMove, folderName);
          if (undoSuccess) {
            locator<NotificationService>().showSnackBar(
              'Restored $count ${count == 1 ? "file" : "files"}',
            );
          } else {
            locator<NotificationService>().showSnackBar(
              'Failed to undo move',
              isError: true,
            );
          }
        },
        duration: const Duration(seconds: 6),
      );
    } else if (mounted) {
      locator<NotificationService>().showSnackBar(
        'Failed to move files',
        isError: true,
      );
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final selectedFiles = _selectedIndices.map((i) => _viewModel.files[i]).toList();
    if (selectedFiles.isEmpty) return;

    final sc = context.snapgroveColors;
    final count = selectedFiles.length;

    String destinationName;
    if (kIsWeb) {
      destinationName = '';
    } else if (Platform.isAndroid) {
      destinationName = 'bin';
    } else if (Platform.isWindows) {
      destinationName = 'Windows Recycle Bin';
    } else {
      destinationName = 'trash';
    }

    final String message = kIsWeb
        ? '$count ${count == 1 ? "file is" : "files are"} being deleted permanently.'
        : '$count ${count == 1 ? "file is" : "files are"} being moved to the $destinationName.';

    final choice = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 330,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Delete $count ${count == 1 ? "file" : "files"}?',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 14,
                          color: sc.muted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Cancel Button (Solid / Primary filled style)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(ctx).pop('cancel'),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!kIsWeb) ...[
                        // Bin Button (Outlined)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(color: isDark ? const Color(0x44FFFFFF) : const Color(0x33000000)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.of(ctx).pop('bin'),
                            child: Text(
                              Platform.isWindows ? 'Windows Recycle Bin' : 'Bin',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Permanently Delete (Destructive red)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE53935),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => Navigator.of(ctx).pop('permanent'),
                          child: const Text(
                            'Permanently Delete',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

    if (choice == 'bin' && mounted) {
      final success = await _viewModel.moveToBin(selectedFiles);
      if (success) {
        _exitSelectionMode();
        locator<NotificationService>().showSnackBar(
          'Moved $count ${count == 1 ? "file" : "files"} to $destinationName',
        );
      } else {
        locator<NotificationService>().showSnackBar('Failed to move files to $destinationName', isError: true);
      }
    } else if (choice == 'permanent' && mounted) {
      final success = await _viewModel.deleteFilesPermanently(selectedFiles);
      if (success) {
        _exitSelectionMode();
        locator<NotificationService>().showSnackBar(
          'Permanently deleted $count ${count == 1 ? "file" : "files"}',
        );
      } else {
        locator<NotificationService>().showSnackBar('Failed to delete files', isError: true);
      }
    }
  }
}

class _RoundBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RoundBackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;
    final iconColor = isDark ? Colors.white : Colors.black;

    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          hoverColor: sc.menuHover,
          splashColor: sc.rippleColor,
          highlightColor: sc.rippleColor.withValues(alpha: 0.15),
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/Back-Btn.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: sc.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: sc.menuHover,
          splashColor: sc.rippleColor,
          highlightColor: sc.rippleColor.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Center(child: childWidget),
          ),
        ),
      ),
    );
  }
}

class _GroupedOptionTile extends StatefulWidget {
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
  State<_GroupedOptionTile> createState() => _GroupedOptionTileState();
}

class _GroupedOptionTileState extends State<_GroupedOptionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const double outerRadius = 10.0;
    const double innerRadius = 3.5;

    final BorderRadius borderRadius;
    if (widget.isFirst && widget.isLast) {
      borderRadius = BorderRadius.circular(outerRadius);
    } else if (widget.isFirst) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(outerRadius),
        topRight: Radius.circular(outerRadius),
        bottomLeft: Radius.circular(innerRadius),
        bottomRight: Radius.circular(innerRadius),
      );
    } else if (widget.isLast) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(innerRadius),
        topRight: Radius.circular(innerRadius),
        bottomLeft: Radius.circular(outerRadius),
        bottomRight: Radius.circular(outerRadius),
      );
    } else {
      borderRadius = BorderRadius.circular(innerRadius);
    }

    final Color normalBg = sc.surfaceMuted;
    final Color hoverBg = isDark ? const Color(0xFF333333) : const Color(0xFFe5e5e5);
    final Color activeBg = isDark ? Colors.white : Colors.black;

    final Color bgColor = widget.isActive
        ? activeBg
        : (_isHovered ? hoverBg : normalBg);

    final Color fgColor = widget.isActive
        ? (isDark ? Colors.black : Colors.white)
        : (widget.isActive || _isHovered ? (isDark ? Colors.white : Colors.black) : sc.muted);

    final Color ripple = widget.isActive
        ? (isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.2))
        : sc.rippleColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: bgColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: ripple,
            highlightColor: ripple.withValues(alpha: 0.15),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                      color: fgColor,
                    ),
                  ),
                  if (widget.isActive) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.check,
                      size: 14,
                      color: fgColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryItem extends StatefulWidget {
  final String path;
  final String? subfolderTag;
  final ThumbnailManager thumbnailManager;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onOpenPreview;
  final VoidCallback? onLongPress;
  final void Function(Offset)? onRightClick;

  const _GalleryItem({
    required this.path, 
    this.subfolderTag,
    required this.thumbnailManager,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionTap,
    this.onOpenPreview,
    this.onLongPress,
    this.onRightClick,
  });

  @override
  State<_GalleryItem> createState() => _GalleryItemState();
}

class _GalleryItemState extends State<_GalleryItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool activeSelection = widget.isSelectionMode && widget.isSelected;
    final Color hoverOverlayColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.3);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.isSelectionMode) {
            widget.onSelectionTap?.call();
          } else {
            widget.onOpenPreview?.call();
          }
        },
        onLongPress: widget.onLongPress,
        onSecondaryTapUp: widget.onRightClick != null
            ? (details) => widget.onRightClick!(details.globalPosition)
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
                _GalleryThumbnail(
                  path: widget.path,
                  thumbnailManager: widget.thumbnailManager,
                ),
                if (widget.subfolderTag != null && widget.subfolderTag!.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        widget.subfolderTag!,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: (_isHovered && !activeSelection) ? 1.0 : 0.0,
                    child: Container(
                      color: hoverOverlayColor,
                    ),
                  ),
                ),
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

class _GalleryThumbnail extends StatefulWidget {
  final String path;
  final ThumbnailManager thumbnailManager;

  const _GalleryThumbnail({
    required this.path,
    required this.thumbnailManager,
  });

  @override
  State<_GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends State<_GalleryThumbnail> {
  String? _webUrl;
  Uint8List? _nativeBytes;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _GalleryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    if (kIsWeb) {
      final cachedUrl = WebImageUtils.getCachedThumbnailUrl(widget.path);
      if (cachedUrl != null) {
        _webUrl = cachedUrl;
        _isError = false;
        return;
      }
      _isError = false;
      WebImageUtils.getThumbnail(widget.path).then((url) {
        if (!mounted) return;
        setState(() {
          _webUrl = url;
          _isError = (url == null);
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _isError = true;
        });
      });
    } else if (Platform.isWindows || widget.path.startsWith('content://')) {
      final cachedBytes = widget.thumbnailManager.getCachedThumbnail(widget.path);
      if (cachedBytes != null) {
        _nativeBytes = cachedBytes;
        _isError = false;
        return;
      }
      _isError = false;
      widget.thumbnailManager.getThumbnail(widget.path).then((bytes) {
        if (!mounted) return;
        if (bytes != null) {
          setState(() {
            _nativeBytes = bytes;
            _isError = false;
          });
        } else {
          locator<FileService>().readFile(widget.path).then((fullBytes) {
            if (!mounted) return;
            setState(() {
              _nativeBytes = fullBytes;
              _isError = (fullBytes == null);
            });
          }).catchError((_) {
            if (!mounted) return;
            setState(() {
              _isError = true;
            });
          });
        }
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _isError = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (_webUrl != null) {
        return Image.network(
          _webUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _ErrorPlaceholder(),
        );
      }
      if (_isError) return _ErrorPlaceholder();
      return const SkeletonLoader(isThumbnail: true);
    }

    if (Platform.isWindows || widget.path.startsWith('content://')) {
      if (_nativeBytes != null) {
        return Image.memory(
          _nativeBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 350,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _ErrorPlaceholder(),
        );
      }
      if (_isError) return _ErrorPlaceholder();
      return const SkeletonLoader(isThumbnail: true);
    }

    return Image.file(
      File(widget.path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 350,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _ErrorPlaceholder(),
    );
  }
}

class _TopSelectionPaneDelegate extends SliverPersistentHeaderDelegate {
  final int selectedCount;
  final List<String> subfolders;
  final VoidCallback onCreateFolder;
  final void Function(String) onMoveToFolder;
  final bool Function(String folder) isFolderEnabled;
  final String? Function(String folder) getFolderTooltip;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final Color accentColor;
  final Color topAmbientColor;
  final Color midAmbientColor;
  final Color bottomAmbientColor;

  _TopSelectionPaneDelegate({
    required this.selectedCount,
    required this.subfolders,
    required this.onCreateFolder,
    required this.onMoveToFolder,
    required this.isFolderEnabled,
    required this.getFolderTooltip,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.accentColor,
    this.topAmbientColor = const Color(0xFFf89838),
    this.midAmbientColor = const Color(0xFFf89838),
    this.bottomAmbientColor = const Color(0xFFf89838),
  });

  double get _height => 92.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: 0.70),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: isDark
                  ? [
                      Color.alphaBlend(topAmbientColor.withValues(alpha: 0.28), backgroundColor.withValues(alpha: 0.70)),
                      Color.alphaBlend(midAmbientColor.withValues(alpha: 0.20), backgroundColor.withValues(alpha: 0.70)),
                      Color.alphaBlend(bottomAmbientColor.withValues(alpha: 0.26), backgroundColor.withValues(alpha: 0.70)),
                    ]
                  : [
                      Color.alphaBlend(topAmbientColor.withValues(alpha: 0.24), backgroundColor.withValues(alpha: 0.70)),
                      Color.alphaBlend(midAmbientColor.withValues(alpha: 0.16), backgroundColor.withValues(alpha: 0.70)),
                      Color.alphaBlend(bottomAmbientColor.withValues(alpha: 0.22), backgroundColor.withValues(alpha: 0.70)),
                    ],
            ),
            border: Border(bottom: BorderSide(color: isDark ? const Color(0x1FFFFFFF) : const Color(0x18000000))),
            boxShadow: [
              BoxShadow(
                color: topAmbientColor.withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: 48,
                spreadRadius: 4,
                offset: const Offset(0, 10),
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
              const SizedBox(height: 8),
              _HorizontalChipsBar(
                subfolders: subfolders,
                onMoveToFolder: onMoveToFolder,
                isFolderEnabled: isFolderEnabled,
                getFolderTooltip: getFolderTooltip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TopSelectionPaneDelegate oldDelegate) => true;
}

class _HorizontalChipsBar extends StatefulWidget {
  final List<String> subfolders;
  final void Function(String) onMoveToFolder;
  final bool Function(String folder) isFolderEnabled;
  final String? Function(String folder) getFolderTooltip;

  const _HorizontalChipsBar({
    required this.subfolders,
    required this.onMoveToFolder,
    required this.isFolderEnabled,
    required this.getFolderTooltip,
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
            itemCount: widget.subfolders.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isEnabled = widget.isFolderEnabled('ROOT');
                return _ActionChip(
                  label: 'ROOT',
                  isRoot: true,
                  isEnabled: isEnabled,
                  tooltip: widget.getFolderTooltip('ROOT'),
                  onTap: isEnabled ? () => widget.onMoveToFolder('ROOT') : null,
                );
              }
              final folder = widget.subfolders[index - 1];
              final isEnabled = widget.isFolderEnabled(folder);
              return _ActionChip(
                label: folder,
                isEnabled: isEnabled,
                tooltip: widget.getFolderTooltip(folder),
                onTap: isEnabled ? () => widget.onMoveToFolder(folder) : null,
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
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Material(
                      color: sc.surfaceElevated.withValues(alpha: 0.85),
                      shape: CircleBorder(
                        side: BorderSide(
                          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.12),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _scroll(-140),
                        hoverColor: sc.menuHover,
                        splashColor: sc.rippleColor,
                        highlightColor: sc.rippleColor.withValues(alpha: 0.15),
                        child: Center(
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
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Material(
                      color: sc.surfaceElevated.withValues(alpha: 0.85),
                      shape: CircleBorder(
                        side: BorderSide(
                          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.12),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _scroll(140),
                        hoverColor: sc.menuHover,
                        splashColor: sc.rippleColor,
                        highlightColor: sc.rippleColor.withValues(alpha: 0.15),
                        child: Center(
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
  final bool Function(String folder) isFolderEnabled;
  final String? Function(String folder) getFolderTooltip;
  final Color topAmbientColor;
  final Color midAmbientColor;
  final Color bottomAmbientColor;

  const _RightSideSelectionPane({
    required this.selectedCount,
    required this.subfolders,
    required this.onCreateFolder,
    required this.onMoveToFolder,
    required this.isFolderEnabled,
    required this.getFolderTooltip,
    this.topAmbientColor = const Color(0xFFf89838),
    this.midAmbientColor = const Color(0xFFf89838),
    this.bottomAmbientColor = const Color(0xFFf89838),
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: 280,
          decoration: BoxDecoration(
            color: (isDark ? sc.surfaceElevated : Colors.white).withValues(alpha: 0.70),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              stops: const [0.0, 0.5, 1.0],
              colors: isDark
                  ? [
                      Color.alphaBlend(
                        topAmbientColor.withValues(alpha: 0.28),
                        sc.surfaceElevated.withValues(alpha: 0.70),
                      ),
                      Color.alphaBlend(
                        midAmbientColor.withValues(alpha: 0.20),
                        sc.surfaceElevated.withValues(alpha: 0.70),
                      ),
                      Color.alphaBlend(
                        bottomAmbientColor.withValues(alpha: 0.26),
                        sc.surfaceElevated.withValues(alpha: 0.70),
                      ),
                    ]
                  : [
                      Color.alphaBlend(
                        topAmbientColor.withValues(alpha: 0.24),
                        Colors.white.withValues(alpha: 0.70),
                      ),
                      Color.alphaBlend(
                        midAmbientColor.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.70),
                      ),
                      Color.alphaBlend(
                        bottomAmbientColor.withValues(alpha: 0.22),
                        sc.surfaceMuted.withValues(alpha: 0.70),
                      ),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: topAmbientColor.withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: 64,
                spreadRadius: 6,
                offset: const Offset(-12, -20),
              ),
              BoxShadow(
                color: bottomAmbientColor.withValues(alpha: isDark ? 0.20 : 0.12),
                blurRadius: 72,
                spreadRadius: 6,
                offset: const Offset(-12, 80),
              ),
            ],
            border: Border(
              left: BorderSide(
                color: isDark ? const Color(0x1FFFFFFF) : const Color(0x18000000),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header (total selected, create folder at top)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
              const SizedBox(height: 2),
              // Subfolders / Tags (2 per row with vertical scroll if overflow, including ROOT)
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.6,
                    ),
                    itemCount: subfolders.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isEnabled = isFolderEnabled('ROOT');
                        return _ActionChip(
                          label: 'ROOT',
                          isRoot: true,
                          isEnabled: isEnabled,
                          tooltip: getFolderTooltip('ROOT'),
                          onTap: isEnabled ? () => onMoveToFolder('ROOT') : null,
                        );
                      }
                      final folder = subfolders[index - 1];
                      final isEnabled = isFolderEnabled(folder);
                      return _ActionChip(
                        label: folder,
                        isEnabled: isEnabled,
                        tooltip: getFolderTooltip(folder),
                        onTap: isEnabled ? () => onMoveToFolder(folder) : null,
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
          color: _isHovered ? hoverBg : defaultBg,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: Colors.black.withValues(alpha: 0.25),
            highlightColor: Colors.black.withValues(alpha: 0.12),
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

class _SelectionActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isEnabled;

  const _SelectionActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  State<_SelectionActionButton> createState() => _SelectionActionButtonState();
}

class _SelectionActionButtonState extends State<_SelectionActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.isEnabled && widget.onTap != null;

    final Color contentColor = enabled
        ? (isDark ? Colors.white : Colors.black)
        : sc.muted.withValues(alpha: 0.4);

    final Color bgColor = enabled
        ? (_isHovered ? sc.menuHover : sc.surfaceMuted)
        : sc.surfaceMuted.withValues(alpha: 0.4);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
          ),
        ),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? widget.onTap : null,
            splashColor: sc.rippleColor,
            highlightColor: sc.rippleColor.withValues(alpha: 0.15),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: contentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: contentColor,
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
  final VoidCallback? onTap;
  final bool isRoot;
  final bool isEnabled;
  final String? tooltip;

  const _ActionChip({
    required this.label,
    required this.onTap,
    this.isRoot = false,
    this.isEnabled = true,
    this.tooltip,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEnabled = widget.isEnabled && widget.onTap != null;

    final Color defaultBg;
    final Color hoverBg;
    final Color defaultBorder;
    final Color hoverBorder;
    final Color contentColor;

    if (widget.isRoot) {
      if (!isEnabled) {
        defaultBg = const Color(0xFFf89838).withValues(alpha: isDark ? 0.06 : 0.04);
        hoverBg = const Color(0xFFf89838).withValues(alpha: isDark ? 0.06 : 0.04);
        defaultBorder = const Color(0xFFf89838).withValues(alpha: 0.25);
        hoverBorder = const Color(0xFFf89838).withValues(alpha: 0.25);
        contentColor = (isDark ? const Color(0xFFf89838) : const Color(0xFFd97818)).withValues(alpha: 0.35);
      } else {
        defaultBg = const Color(0xFFf89838).withValues(alpha: isDark ? 0.22 : 0.16);
        hoverBg = const Color(0xFFf89838).withValues(alpha: isDark ? 0.35 : 0.28);
        defaultBorder = const Color(0xFFf89838);
        hoverBorder = const Color(0xFFf89838);
        contentColor = isDark ? const Color(0xFFf89838) : const Color(0xFFd97818);
      }
    } else {
      if (!isEnabled) {
        defaultBg = isDark ? const Color(0xFF141414).withValues(alpha: 0.4) : const Color(0xFFF0F0F0).withValues(alpha: 0.4);
        hoverBg = isDark ? const Color(0xFF141414).withValues(alpha: 0.4) : const Color(0xFFF0F0F0).withValues(alpha: 0.4);
        defaultBorder = isDark ? const Color(0x10FFFFFF) : const Color(0x0C000000);
        hoverBorder = isDark ? const Color(0x10FFFFFF) : const Color(0x0C000000);
        contentColor = (isDark ? Colors.white70 : Colors.black87).withValues(alpha: 0.3);
      } else {
        defaultBg = isDark ? const Color(0xFF1a1a1a).withValues(alpha: 0.75) : const Color(0xFFf3f3f3).withValues(alpha: 0.75);
        hoverBg = isDark ? const Color(0xFF282828).withValues(alpha: 0.85) : const Color(0xFFe5e5e5).withValues(alpha: 0.85);
        defaultBorder = isDark ? const Color(0x22FFFFFF) : const Color(0x18000000);
        hoverBorder = isDark ? const Color(0x44FFFFFF) : const Color(0x33000000);
        contentColor = isDark ? Colors.white70 : Colors.black87;
      }
    }

    Widget chip = MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isEnabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isEnabled) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isHovered ? hoverBorder : defaultBorder,
          ),
          boxShadow: (_isHovered && isEnabled)
              ? [
                  BoxShadow(
                    color: widget.isRoot
                        ? const Color(0xFFf89838).withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: _isHovered ? hoverBg : defaultBg,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isEnabled ? widget.onTap : null,
            splashColor: const Color(0xFFf89838).withValues(alpha: 0.35),
            highlightColor: const Color(0xFFf89838).withValues(alpha: 0.18),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isRoot ? Icons.home_outlined : Icons.folder_outlined,
                    size: 14,
                    color: contentColor,
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
                        fontWeight: FontWeight.w700,
                        color: contentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      chip = Tooltip(
        message: widget.tooltip!,
        child: chip,
      );
    }

    return chip;
  }
}

class _DropdownMenuOptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DropdownMenuOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_DropdownMenuOptionTile> createState() => _DropdownMenuOptionTileState();
}

class _DropdownMenuOptionTileState extends State<_DropdownMenuOptionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: _isHovered ? sc.menuHover : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: sc.rippleColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 19,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: sc.muted,
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
