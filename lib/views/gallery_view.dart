import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  // Selection Mode
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = <int>{};

  // Context Menu
  OverlayEntry? _contextMenuEntry;

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

  @override
  void dispose() {
    _removeContextMenu();
    super.dispose();
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

  void _removeContextMenu() {
    _contextMenuEntry?.remove();
    _contextMenuEntry = null;
  }

  void _showContextMenu(BuildContext context, Offset position, int index) {
    _removeContextMenu();

    final sc = context.snapgroveColors;

    _contextMenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeContextMenu,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(minWidth: 160),
                decoration: BoxDecoration(
                  color: sc.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sc.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ContextMenuItem(
                      icon: Icons.checklist,
                      label: 'Select',
                      onTap: () {
                        _removeContextMenu();
                        _enterSelectionMode(initialIndex: index);
                      },
                    ),
                    _ContextMenuItem(
                      icon: Icons.select_all,
                      label: 'Select All',
                      onTap: () {
                        _removeContextMenu();
                        _selectAll();
                      },
                    ),
                    const Divider(height: 1, thickness: 1),
                    _ContextMenuItem(
                      icon: Icons.preview,
                      label: 'Preview',
                      onTap: () {
                        _removeContextMenu();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ImagePreviewView(
                              files: _viewModel.files,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_contextMenuEntry!);
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
              scrollCacheExtent: const ScrollCacheExtent.pixels(1500),
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
                    onPressed: () => _isSelectionMode ? _exitSelectionMode() : _showExitConfirmation(context),
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
                            _IconSquare(
                              svgPath: 'assets/icons/check.svg',
                              onTap: _selectAll,
                            ),
                            const SizedBox(width: 10),
                            _IconSquare(
                              svgPath: 'assets/icons/Back-Btn.svg',
                              onTap: _exitSelectionMode,
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
                                svgPath: 'assets/icons/check.svg',
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
                        ? Text(
                            widget.title,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          )
                        : null,
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
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedIndices.contains(index),
                            onSelectionTap: () => _toggleSelection(index),
                            onLongPress: () => _enterSelectionMode(initialIndex: index),
                            onRightClick: (position) => _showContextMenu(context, position, index),
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
            bottomSheet: _isSelectionMode ? _buildSelectionActionBar() : null,
          );
        },
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

    Widget child = Container(
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
    );

    if (isSelectionMode) {
      child = Stack(
        children: [
          child,
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSelectionTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? sc.accent.withValues(alpha: 0.3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected 
                        ? Border.all(color: sc.accent, width: 3)
                        : null,
                  ),
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? sc.accent : Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.transparent : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
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
      onSecondaryTapDown: onRightClick != null
          ? (details) => onRightClick!(details.globalPosition)
          : null,
      child: child,
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
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
