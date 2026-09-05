import 'dart:io';
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

  int _getEffectiveColumns(double width) {
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
    final effectiveColumns = _getEffectiveColumns(width);

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
              body: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                scrollCacheExtent: const ScrollCacheExtent.pixels(1500),
                slivers: [
                  SliverAppBar(
                    expandedHeight: (width < 400) ? 128.0 : 120.0,
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
                              Text(
                                '${_selectedIndices.length} selected',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 13,
                                  color: sc.muted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Tooltip(
                                message: 'Select all',
                                child: _IconSquare(
                                  icon: Icons.done_all,
                                  onTap: _selectAll,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _IconSquare(
                                svgPath: 'assets/icons/Back-Btn.svg',
                                onTap: () => _confirmExitSelectionMode(context),
                              ),
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
            ),
            bottomSheet: _isSelectionMode ? _buildSelectionActionBar() : null,
          );
        },
      ),
    ),
  );
  }

  Widget _buildSelectionActionBar() {
    final sc = context.snapgroveColors;
    final subfolders = _viewModel.subfolders;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: sc.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '${_selectedIndices.length} selected',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    color: sc.muted,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selectedIndices.isNotEmpty ? _showCreateFolderDialog : null,
                  icon: Icon(Icons.create_new_folder, size: 18, color: sc.accent),
                  label: Text(
                    'Create Folder',
                    style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: sc.accent),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _exitSelectionMode,
                  child: Text(
                    'Done',
                    style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: sc.muted),
                  ),
                ),
              ],
            ),
            if (subfolders.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...subfolders.map((folder) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ActionChip(
                        label: folder,
                        onTap: () => _moveSelectedToFolder(folder),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
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

    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(10) : Radius.zero,
      bottom: isLast ? const Radius.circular(10) : Radius.zero,
    );

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
            border: Border.all(
              color: isActive ? Colors.transparent : sc.border.withValues(alpha: 0.6),
              width: 0.8,
            ),
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

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sc.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sc.accent.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: sc.accent,
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
