import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../core/app_constants.dart';
import '../core/locator.dart';
import '../models/folder_node.dart';
import '../viewmodels/gallery_view_model.dart';
import '../viewmodels/app_view_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_blur.dart';
import '../theme/snap_symbols.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/web_image_utils.dart';
import '../services/thumbnail_manager.dart';
import '../services/notification_service.dart';
import 'image_preview_view.dart';
import 'manage_folders_view.dart';
import 'widgets/folder_tree_picker_modal.dart';
import 'widgets/m3_switch.dart';
import 'theme_dialog.dart';
import 'settings_view.dart';

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

  // Grid Configuration
  int? _userSelectedColumns;

  // Selection Mode (delegated to GalleryViewModel as single source of truth)
  bool get _isSelectionMode => _viewModel.isSelectionMode;

  // Floating progress card state during file moving in selection mode
  bool _isMovingFiles = false;
  String? _movingFilesStatus;

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

  @override
  void dispose() {
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
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



  void _enterSelectionMode({int? initialIndex, String? initialPath}) {
    _viewModel.enterSelectionMode(
      initialIndex: initialIndex,
      initialPath: initialPath,
    );
  }

  void _exitSelectionMode() {
    _viewModel.exitSelectionMode();
  }

  void _toggleSelection(dynamic item) {
    _viewModel.toggleSelection(item);
  }

  void _selectAll() {
    _viewModel.selectAll();
  }

  void _unselectAll() {
    _viewModel.clearSelection();
  }

  Future<void> _showContextMenu(BuildContext context, Offset position, int index) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    const double menuWidth = 190.0;
    const double menuHeight = 140.0;

    final left = position.dx + menuWidth > screenSize.width - 12
        ? (screenSize.width - menuWidth - 12).clamp(12.0, double.infinity)
        : position.dx;
    final top = position.dy + menuHeight > screenSize.height - 12
        ? (screenSize.height - menuHeight - 12).clamp(12.0, double.infinity)
        : position.dy;

    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Context Menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(ctx).pop(),
                onSecondaryTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                  child: Container(
                    width: menuWidth,
                    decoration: BoxDecoration(
                      color: AppBlur.getBackgroundColor(
                        (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.85),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildContextMenuItem(
                            icon: SnapSymbols.select_check_box,
                            label: 'Select',
                            isDark: isDark,
                            onTap: () => Navigator.of(ctx).pop('select'),
                          ),
                          _buildContextMenuItem(
                            icon: SnapSymbols.select_all,
                            label: 'Select All',
                            isDark: isDark,
                            onTap: () => Navigator.of(ctx).pop('select_all'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                            ),
                          ),
                          _buildContextMenuItem(
                            icon: SnapSymbols.preview,
                            label: 'Preview',
                            isDark: isDark,
                            onTap: () => Navigator.of(ctx).pop('preview'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
              onFileMoved: (file, folder) async => (await _viewModel.moveFilesToFolder([file], folder)).isSuccess,
              onFileDeleted: (file) => _viewModel.deleteFilesPermanently([file]),
                            onFileMoveToBin: (file) => _viewModel.moveToBin([file]),
            ),
          ),
        );
        break;
    }
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      hoverColor: isDark ? const Color(0x22FFFFFF) : const Color(0x12000000),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 10),
            Text(
              label,
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
    );
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
                      filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
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
                                      SnapSymbols.snippet_folder_outlined,
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
                                    M3Switch(
                                      value: _viewModel.includeSubfolders,
                                      activeColor: sc.accent,
                                      onChanged: (val) {
                                        _viewModel.setIncludeSubfolders(val);
                                        setStateDropdown(() {});
                                      },
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
                              icon: SnapSymbols.grid_view,
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
                            // Option 2: Sort
                            _DropdownMenuOptionTile(
                              icon: SnapSymbols.sort_rounded,
                              label: 'Sort',
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _showSortDialog();
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: Divider(
                                color: isDark ? const Color(0x1FFFFFFF) : const Color(0x18000000),
                                height: 1,
                              ),
                            ),
                            // Option 3: Theme
                            _DropdownMenuOptionTile(
                              icon: SnapSymbols.palette_outlined,
                              label: 'Theme',
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _showThemeDialog();
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: Divider(
                                color: isDark ? const Color(0x1FFFFFFF) : const Color(0x18000000),
                                height: 1,
                              ),
                            ),
                            // Option 4: Settings
                            _DropdownMenuOptionTile(
                              icon: SnapSymbols.settings_outlined,
                              label: 'Settings',
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _openSettings();
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
                  filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                  child: Container(
                    width: 340,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
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

  Future<void> _openSettings() async {
    final oldSort = _viewModel.folderSortOrder;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsView(),
      ),
    );
    if (!mounted) return;

    String newSort = oldSort;
    try {
      if (locator.isRegistered<SettingsService>()) {
        newSort = locator<SettingsService>().folderSortOrder;
      } else {
        final saved = await locator<StorageService>().read('settings', 'folder_sort_order');
        if (saved is String && saved.isNotEmpty) newSort = saved;
      }
    } catch (_) {}

    if (newSort != oldSort) {
      await _viewModel.refreshTagsSmoothly(newSortOrder: newSort);
    }
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
                  filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                  child: Container(
                    width: 310,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
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
    if (_viewModel.selectedCount == 0) {
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
                filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
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
                        'Your current selection of ${_viewModel.selectedCount} item(s) will be lost.',
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
                filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
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
            final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
            final isDesktop = !isAndroid && width >= 720;
            final useSidePane = _isSelectionMode && isDesktop;
            final useTopPane = _isSelectionMode && !isDesktop;
            final effectiveColumns = _getEffectiveColumns(width, isRightPaneOpen: useSidePane);

            final isLoading = _viewModel.isLoading || _isTransitioning;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sc = context.snapgroveColors;
            
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Stack(
                children: [
                  useSidePane
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
                              selectedCount: _viewModel.selectedCount,
                              subfolders: _viewModel.subfolders,
                              isTagsLoading: _viewModel.isTagsLoading,
                              onCreateFolder: _showCreateFolderDialog,
                              onMoveToFolder: _moveSelectedToFolder,
                              onRenameFolder: (folder, pos) => _showRenameFolderMenu(context, folder, pos),
                              isFolderEnabled: _isFolderActionEnabled,
                              getFolderTooltip: _getFolderActionTooltip,
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
                  if (_isMovingFiles)
                    _buildMovingProgressFloatingCard(sc, isDark),
                ],
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
          expandedHeight: _isSelectionMode ? kToolbarHeight : ((width < 400) ? 132.0 : 136.0),
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
                        icon: SnapSymbols.done_all,
                        label: 'Select All',
                        isEnabled: _viewModel.files.isNotEmpty && _viewModel.selectedCount < _viewModel.files.length,
                        onTap: _selectAll,
                      ),
                      const SizedBox(width: 8),
                      _SelectionActionButton(
                        icon: SnapSymbols.deselect,
                        label: 'Unselect',
                        isEnabled: _viewModel.selectedCount > 0,
                        onTap: _unselectAll,
                      ),
                      const SizedBox(width: 8),
                      _SelectionActionButton(
                        icon: SnapSymbols.delete_outline_rounded,
                        label: 'Delete',
                        isEnabled: _viewModel.selectedCount > 0,
                        onTap: _showDeleteConfirmationDialog,
                      ),
                      const SizedBox(width: 8),
                      _SelectionActionButton(
                        icon: SnapSymbols.settings_outlined,
                        label: 'Settings',
                        isEnabled: true,
                        onTap: _openSettings,
                      ),
                    ] else ...[
                      IconButton(
                        tooltip: 'Delete selected',
                        icon: Icon(
                          SnapSymbols.delete_outline_rounded,
                          size: 22,
                          color: _viewModel.selectedCount > 0
                              ? (isDark ? Colors.white : Colors.black)
                              : sc.muted.withValues(alpha: 0.4),
                        ),
                        onPressed: _viewModel.selectedCount > 0 ? _showDeleteConfirmationDialog : null,
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(
                          SnapSymbols.more_vert,
                          size: 22,
                          color: isDark ? Colors.white : Colors.black,
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
                          } else if (val == 'settings') {
                            _openSettings();
                          }
                        },
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem(
                              value: 'select_all',
                              enabled: _viewModel.files.isNotEmpty && _viewModel.selectedCount < _viewModel.files.length,
                              child: Row(
                                children: [
                                  Icon(
                                    SnapSymbols.done_all,
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
                              enabled: _viewModel.selectedCount > 0,
                              child: Row(
                                children: [
                                  Icon(
                                    SnapSymbols.deselect,
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
                            if (_viewModel.selectedCount > 0) ...[
                              const PopupMenuDivider(height: 1),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      SnapSymbols.delete_outline_rounded,
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
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem(
                              value: 'settings',
                              child: Row(
                                children: [
                                  Icon(
                                    SnapSymbols.settings_outlined,
                                    size: 18,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Settings',
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
                        icon: SnapSymbols.select_check_box,
                        onTap: () => _enterSelectionMode(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Manage Folders (tags)',
                      child: _IconSquare(
                        icon: SnapSymbols.folder_open,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ManageFoldersView(
                                rootPath: widget.path,
                                rootTitle: widget.title,
                              ),
                            ),
                          ).then((_) async {
                            if (!mounted) return;
                            await _viewModel.loadFiles();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Options',
                      child: _IconSquare(
                        icon: SnapSymbols.more_vert,
                        onTap: () => _showMoreMenuDropdown(context, width),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          flexibleSpace: !_isSelectionMode
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final topPadding = MediaQuery.paddingOf(context).top;
                    final double currentHeight = constraints.maxHeight;
                    final double minHeight = kToolbarHeight + topPadding;
                    final double maxHeight = ((width < 400) ? 132.0 : 136.0) + topPadding;
                    final double delta = (maxHeight - minHeight).abs();
                    final double t = delta > 0 ? ((currentHeight - minHeight) / delta).clamp(0.0, 1.0) : 0.0;

                    final double expandedOpacity = Curves.easeIn.transform((t - 0.25).clamp(0.0, 0.75) / 0.75);
                    final double collapsedOpacity = Curves.easeOut.transform((0.35 - t).clamp(0.0, 0.35) / 0.35);

                    final folderName = _getDisplayFolderName(widget.path, widget.title);
                    final double rightPad = !isLoading && _viewModel.files.isNotEmpty
                        ? (width < 600 ? 152.0 : 172.0)
                        : 48.0;

                    return IgnorePointer(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Collapsed Title (Header row between Back button and Action buttons)
                          if (collapsedOpacity > 0.01)
                            Positioned(
                              top: topPadding,
                              left: 56.0,
                              right: rightPad,
                              height: kToolbarHeight,
                              child: Opacity(
                                opacity: collapsedOpacity,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    folderName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Expanded Title (Below top action row, spanning full width as marked in user's image)
                          if (expandedOpacity > 0.01)
                            Positioned(
                              left: 20.0,
                              right: 20.0,
                              bottom: 12.0,
                              child: Opacity(
                                opacity: expandedOpacity,
                                child: Text(
                                  folderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: width < 380 ? 20.0 : (width < 600 ? 22.0 : 26.0),
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                )
              : null,
        ),
        if (useTopPane)
          SliverPersistentHeader(
            pinned: true,
            delegate: _TopSelectionPaneDelegate(
              selectedCount: _viewModel.selectedCount,
              subfolders: _viewModel.subfolders,
              isTagsLoading: _viewModel.isTagsLoading,
              onCreateFolder: _showCreateFolderDialog,
              onMoveToFolder: _moveSelectedToFolder,
              onRenameFolder: (folder, pos) => _showRenameFolderMenu(context, folder, pos),
              isFolderEnabled: _isFolderActionEnabled,
              getFolderTooltip: _getFolderActionTooltip,
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
                  Icon(SnapSymbols.photo_library_outlined, size: 48, color: sc.muted.withValues(alpha: 0.5)),
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
                    key: ValueKey<String>(path),
                    path: path,
                    subfolderTag: subfolderTag,
                    thumbnailManager: _thumbnailManager,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _viewModel.isPathSelected(path),
                    onSelectionTap: () => _toggleSelection(path),
                    onOpenPreview: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImagePreviewView(
                            files: _viewModel.files,
                            initialIndex: index,
                            directoryPath: _viewModel.path,
                            subfolders: _viewModel.subfolders,
                            onFolderCreated: (name) => _viewModel.createSubfolder(name),
                            onFileMoved: (file, folder) async => (await _viewModel.moveFilesToFolder([file], folder)).isSuccess,
                            onFileDeleted: (file) => _viewModel.deleteFilesPermanently([file]),
                            onFileMoveToBin: (file) => _viewModel.moveToBin([file]),
                          ),
                        ),
                      );
                    },
                    onLongPress: () {
                      if (_isSelectionMode) {
                        _toggleSelection(path);
                      } else {
                        _enterSelectionMode(initialPath: path);
                      }
                    },
                    onRightClick: (position) => _showContextMenu(context, position, index),
                  );
                },
                childCount: _viewModel.files.length,
                findChildIndexCallback: (Key key) {
                  if (key is ValueKey<String>) {
                    final normalizedKey = GalleryViewModel.normalizePathKey(key.value);
                    final idx = _viewModel.files.indexWhere(
                      (f) => GalleryViewModel.normalizePathKey(f) == normalizedKey,
                    );
                    return idx != -1 ? idx : null;
                  }
                  return null;
                },
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
                filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
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
    final selectedFiles = _viewModel.getSelectedFiles();
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
    final selectedFiles = _viewModel.getSelectedFiles();
    if (selectedFiles.isEmpty) return null;
    final enabled = _isFolderActionEnabled(folderName);
    if (enabled) return null;
    if (folderName == 'ROOT' || folderName.isEmpty) {
      return 'All selected images are already in root';
    }
    return 'All selected images are already in $folderName';
  }

  // Move selected files to the specified folder
  Future<void> _moveSelectedToFolder(String folderName) async {
    final selectedFiles = _viewModel.getSelectedFiles();
    if (selectedFiles.isEmpty) return;

    // Check if the target folder has children
    final tree = _viewModel.folderTree;
    final matchingNode = tree?.findByRelPath(folderName);
    if (matchingNode != null && matchingNode.hasChildren) {
      final currentTags = selectedFiles.map((f) => _viewModel.getSubfolderTag(f) ?? 'ROOT').toList();
      final chosenRelPath = await FolderTreePickerModal.show(
        context,
        rootNode: tree,
        currentFolderName: folderName,
        currentSelectedTags: currentTags,
      );
      if (chosenRelPath == null) return;
      return _moveSelectedToFolder(chosenRelPath);
    }

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

    _exitSelectionMode();

    final count = filesToMove.length;
    setState(() {
      _isMovingFiles = true;
      _movingFilesStatus = 'Moving $count ${count == 1 ? "file" : "files"} to $folderName...';
    });

    try {
      final result = await _viewModel.moveFilesToFolder(filesToMove, folderName);
      if (result.isSuccess && mounted) {
        locator<NotificationService>().showSnackBar(
          'Moved $count ${count == 1 ? "file" : "files"} to $folderName',
          actionLabel: 'Undo',
          onAction: () async {
            if (mounted) {
              setState(() {
                _isMovingFiles = true;
                _movingFilesStatus = 'Restoring $count ${count == 1 ? "file" : "files"}...';
              });
            }
            try {
              final undoSuccess = await _viewModel.undoMoveFiles(filesToMove, folderName, records: result.succeededRecords);
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
            } finally {
              if (mounted) {
                setState(() {
                  _isMovingFiles = false;
                  _movingFilesStatus = null;
                });
              }
            }
          },
          duration: const Duration(seconds: 6),
        );
      } else if (result.isPartial && mounted) {
        locator<NotificationService>().showSnackBar(
          'Moved ${result.totalMoved} ${result.totalMoved == 1 ? "file" : "files"} to $folderName (${result.totalFailed} failed)',
          actionLabel: 'Undo',
          onAction: () async {
            if (mounted) {
              setState(() {
                _isMovingFiles = true;
                _movingFilesStatus = 'Restoring ${result.totalMoved} ${result.totalMoved == 1 ? "file" : "files"}...';
              });
            }
            try {
              final undoSuccess = await _viewModel.undoMoveFiles(filesToMove, folderName, records: result.succeededRecords);
              if (undoSuccess) {
                locator<NotificationService>().showSnackBar(
                  'Restored ${result.totalMoved} ${result.totalMoved == 1 ? "file" : "files"}',
                );
              } else {
                locator<NotificationService>().showSnackBar(
                  'Failed to undo move',
                  isError: true,
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isMovingFiles = false;
                  _movingFilesStatus = null;
                });
              }
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
    } finally {
      if (mounted) {
        setState(() {
          _isMovingFiles = false;
          _movingFilesStatus = null;
        });
      }
    }
  }

  Widget _buildMovingProgressFloatingCard(SnapgroveColors sc, bool isDark) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 24 + bottomInset,
      left: 16,
      right: 16,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sc.accent.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(sc.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _movingFilesStatus ?? 'Moving files...',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: sc.accent.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(sc.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameFolderMenu(BuildContext context, String folder, Offset? position) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final pos = position ?? const Offset(200, 300);

    const double menuWidth = 160.0;
    const double menuHeight = 56.0;

    final left = pos.dx + menuWidth > screenSize.width - 12
        ? (screenSize.width - menuWidth - 12).clamp(12.0, double.infinity)
        : pos.dx;
    final top = pos.dy + menuHeight > screenSize.height - 12
        ? (screenSize.height - menuHeight - 12).clamp(12.0, double.infinity)
        : pos.dy;

    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Rename Menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(ctx).pop(),
                onSecondaryTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                  child: Container(
                    width: menuWidth,
                    decoration: BoxDecoration(
                      color: AppBlur.getBackgroundColor(
                        (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.85),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: _buildContextMenuItem(
                        icon: SnapSymbols.drive_file_rename_outline_rounded,
                        label: 'Rename',
                        isDark: isDark,
                        onTap: () => Navigator.of(ctx).pop('rename'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (selected == 'rename' && mounted) {
      _showRenameTagDialog(folder);
    }
  }

  Future<void> _showRenameTagDialog(String oldName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: oldName);

    final newName = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, a1, a2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.92)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rename Folder',
                          style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        style: const TextStyle(
                            fontFamily: 'JetBrains Mono', fontSize: 13),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel',
                                style: TextStyle(fontFamily: 'JetBrains Mono')),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDark ? Colors.white : Colors.black,
                              foregroundColor:
                                  isDark ? Colors.black : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () =>
                                Navigator.of(ctx).pop(controller.text.trim()),
                            child: const Text('Save',
                                style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontWeight: FontWeight.w700)),
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
    );

    if (newName != null && newName.isNotEmpty && newName != oldName && mounted) {
      final root = _viewModel.path;
      final tree = _viewModel.folderTree ?? await locator<FileService>().getFolderTree(root);
      FolderNode? targetNode;
      if (tree != null) {
        targetNode = tree.findByRelPath(oldName);
        targetNode ??= tree.children.cast<FolderNode?>().firstWhere(
              (c) => c?.name.toLowerCase() == oldName.toLowerCase(),
              orElse: () => null,
            );
      }
      final folderPath = targetNode?.path ?? p.join(root, oldName);
      final ok = await locator<FileService>().renameFolderNode(folderPath, newName);
      if (ok && mounted) {
        locator<NotificationService>().showSnackBar('Renamed to "$newName"');
        await _viewModel.refreshTagsSmoothly();
      } else if (mounted) {
        locator<NotificationService>().showSnackBar('Failed to rename folder', isError: true);
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final selectedFiles = _viewModel.getSelectedFiles();
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

    final String singleName = count == 1
        ? p.basename(selectedFiles.first).replaceAll('%2F', '/').split('/').last
        : '';
    final String truncatedSingleName = AppConstants.truncateFileName(singleName, maxLength: 28);
    final String message = kIsWeb
        ? (count == 1
            ? 'Are you sure you want to permanently delete "$truncatedSingleName"?'
            : '$count files are being deleted permanently.')
        : (count == 1
            ? '"$truncatedSingleName" is being moved to the $destinationName.'
            : '$count files are being moved to the $destinationName.');

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
                filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                child: Container(
                  width: 330,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
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
                        count == 1 ? 'Delete image?' : 'Delete $count files?',
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
      _exitSelectionMode();
      final success = await _viewModel.moveToBin(selectedFiles);
      if (success) {
        final settings = locator<SettingsService>();
        final isOtherPc = !kIsWeb && (defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
        if (isOtherPc && !settings.binFirstMoveDone && !settings.isBinPasswordSet) {
          settings.markBinFirstMoveDone();
          locator<NotificationService>().showSnackBar(
            'Moved $count ${count == 1 ? "file" : "files"} to $destinationName',
            actionLabel: 'Set Bin Password',
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsView(highlightBinAuth: true),
                ),
              );
            },
            duration: const Duration(seconds: 6),
          );
        } else {
          locator<NotificationService>().showSnackBar(
            'Moved $count ${count == 1 ? "file" : "files"} to $destinationName',
          );
        }
      } else {
        locator<NotificationService>().showSnackBar('Failed to move files to $destinationName', isError: true);
      }
    } else if (choice == 'permanent' && mounted) {
      _exitSelectionMode();
      final success = await _viewModel.deleteFilesPermanently(selectedFiles);
      if (success) {
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
    final isDesktopOrWeb = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final message = isDesktopOrWeb ? 'Back (Esc)' : 'Back';

    return Tooltip(
      message: message,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            customBorder: const CircleBorder(),
            onTap: onTap,
            hoverColor: sc.menuHover,
            splashColor: sc.rippleColor,
            highlightColor: sc.rippleColor.withValues(alpha: 0.15),
            child: Center(
              child: Icon(
                SnapSymbols.arrow_back_ios_new,
                size: 20,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconSquare({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : Colors.black;
    final childWidget = Icon(icon, size: 20, color: fgColor);

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
          mouseCursor: SystemMouseCursors.click,
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
                      SnapSymbols.check,
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
    super.key,
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
                      SnapSymbols.done_all,
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
  final bool isTagsLoading;
  final VoidCallback onCreateFolder;
  final void Function(String) onMoveToFolder;
  final void Function(String folder, Offset? position)? onRenameFolder;
  final bool Function(String folder) isFolderEnabled;
  final String? Function(String folder) getFolderTooltip;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final Color accentColor;

  _TopSelectionPaneDelegate({
    required this.selectedCount,
    required this.subfolders,
    this.isTagsLoading = false,
    required this.onCreateFolder,
    required this.onMoveToFolder,
    this.onRenameFolder,
    required this.isFolderEnabled,
    required this.getFolderTooltip,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.accentColor,
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
        filter: AppBlur.filter(sigmaX: 24, sigmaY: 24)!,
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppBlur.getBackgroundColor(backgroundColor.withValues(alpha: isDark ? 0.85 : 0.92)),
            border: Border(bottom: BorderSide(color: isDark ? const Color(0x1FFFFFFF) : const Color(0x18000000))),
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
                isTagsLoading: isTagsLoading,
                onMoveToFolder: onMoveToFolder,
                onRenameFolder: onRenameFolder,
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
  final bool isTagsLoading;
  final void Function(String) onMoveToFolder;
  final void Function(String folder, Offset? position)? onRenameFolder;
  final bool Function(String folder) isFolderEnabled;
  final String? Function(String folder) getFolderTooltip;

  const _HorizontalChipsBar({
    required this.subfolders,
    this.isTagsLoading = false,
    required this.onMoveToFolder,
    this.onRenameFolder,
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

  Widget _buildSkeletonChips(BuildContext context, SnapgroveColors sc, bool isDark) {
    return ListView.separated(
      key: const ValueKey('tags_skeleton_chips'),
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        final widths = [72.0, 88.0, 78.0, 96.0, 68.0, 84.0];
        final w = widths[index % widths.length];
        return _SkeletonChip(width: w, isRoot: index == 0);
      },
    );
  }

  Widget _buildRealChips(BuildContext context, SnapgroveColors sc, bool isDark, Color bgColor) {
    return Stack(
      key: ValueKey('tags_real_${widget.subfolders.join("_")}'),
      children: [
        Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent && _scrollController.hasClients) {
              final delta = pointerSignal.scrollDelta.dy != 0
                  ? pointerSignal.scrollDelta.dy
                  : pointerSignal.scrollDelta.dx;
              _scroll(delta);
            }
          },
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
                onRename: (pos) => widget.onRenameFolder?.call(folder, pos),
              );
            },
          ),
        ),
        if (_canScrollLeft)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 36,
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
                          SnapSymbols.chevron_left,
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
              width: 36,
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
                          SnapSymbols.chevron_right,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      height: 34,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: widget.isTagsLoading
            ? _buildSkeletonChips(context, sc, isDark)
            : _buildRealChips(context, sc, isDark, bgColor),
      ),
    );
  }
}

class _RightSideSelectionPane extends StatelessWidget {
  final int selectedCount;
  final List<String> subfolders;
  final bool isTagsLoading;
  final VoidCallback onCreateFolder;
  final void Function(String) onMoveToFolder;
  final void Function(String folder, Offset? position)? onRenameFolder;
  final bool Function(String folder) isFolderEnabled;
  final String? Function(String folder) getFolderTooltip;

  const _RightSideSelectionPane({
    required this.selectedCount,
    required this.subfolders,
    this.isTagsLoading = false,
    required this.onCreateFolder,
    required this.onMoveToFolder,
    this.onRenameFolder,
    required this.isFolderEnabled,
    required this.getFolderTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: AppBlur.filter(sigmaX: 24, sigmaY: 24)!,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: 280,
          decoration: BoxDecoration(
            color: AppBlur.getBackgroundColor((isDark ? sc.surfaceElevated : Colors.white).withValues(alpha: 0.85)),
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: isTagsLoading
                      ? GridView.builder(
                          key: const ValueKey('grid_skeleton_chips'),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.6,
                          ),
                          itemCount: 6,
                          itemBuilder: (context, index) {
                            return _SkeletonChip(
                              width: double.infinity,
                              isRoot: index == 0,
                            );
                          },
                        )
                      : Scrollbar(
                          key: ValueKey('grid_real_${subfolders.join("_")}'),
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
                                onRename: (pos) => onRenameFolder?.call(folder, pos),
                              );
                            },
                          ),
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
                  Icon(SnapSymbols.create_new_folder, size: 16, color: Color(0xFF000000)),
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

class _SkeletonChip extends StatefulWidget {
  final double width;
  final bool isRoot;

  const _SkeletonChip({
    required this.width,
    this.isRoot = false,
  });

  @override
  State<_SkeletonChip> createState() => _SkeletonChipState();
}

class _SkeletonChipState extends State<_SkeletonChip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color baseColor;
    final Color highlightColor;
    final Color borderColor;

    if (widget.isRoot) {
      baseColor = const Color(0xFFf89838).withValues(alpha: isDark ? 0.12 : 0.08);
      highlightColor = const Color(0xFFf89838).withValues(alpha: isDark ? 0.28 : 0.20);
      borderColor = const Color(0xFFf89838).withValues(alpha: 0.35);
    } else {
      baseColor = isDark ? const Color(0xFF222222) : const Color(0xFFE8E8E8);
      highlightColor = isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5);
      borderColor = isDark ? const Color(0x18FFFFFF) : const Color(0x12000000);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
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

class _ActionChip extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isRoot;
  final bool isEnabled;
  final String? tooltip;
  final void Function(Offset?)? onRename;

  const _ActionChip({
    required this.label,
    required this.onTap,
    this.isRoot = false,
    this.isEnabled = true,
    this.tooltip,
    this.onRename,
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
            onLongPress: (!widget.isRoot && widget.onRename != null)
                ? () => widget.onRename!(null)
                : null,
            splashColor: const Color(0xFFf89838).withValues(alpha: 0.35),
            highlightColor: const Color(0xFFf89838).withValues(alpha: 0.18),
            hoverColor: Colors.transparent,
            child: GestureDetector(
              onSecondaryTapUp: (!widget.isRoot && widget.onRename != null)
                  ? (details) => widget.onRename!(details.globalPosition)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isRoot ? SnapSymbols.home_outlined : SnapSymbols.folder_outlined,
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
                  SnapSymbols.chevron_right,
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
      child: Center(child: Icon(SnapSymbols.broken_image, color: sc.muted)),
    );
  }
}
