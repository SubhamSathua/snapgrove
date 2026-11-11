import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/locator.dart';
import '../models/folder_node.dart';
import '../services/file_service.dart';
import '../services/notification_service.dart';
import '../services/thumbnail_manager.dart';
import '../theme/app_theme.dart';
import 'widgets/folder_tree_picker_modal.dart';
import 'image_preview_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ManageFoldersView
// ─────────────────────────────────────────────────────────────────────────────

class ManageFoldersView extends StatefulWidget {
  final String rootPath;
  final String rootTitle;

  const ManageFoldersView({
    super.key,
    required this.rootPath,
    required this.rootTitle,
  });

  @override
  State<ManageFoldersView> createState() => _ManageFoldersViewState();
}

class _ManageFoldersViewState extends State<ManageFoldersView> {
  final _fileService = locator<FileService>();
  final _notificationService = locator<NotificationService>();
  final _thumbnailManager = ThumbnailManager();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  FolderNode? _rootTree;
  bool _isRootHidden = false;

  // Navigation stack within the tree: stores relPath (empty string = root)
  final List<String> _navigationStack = [''];

  // Current folder's images & multi-selection
  List<String> _currentImages = [];
  final Set<String> _selectedImagePaths = {};
  bool _isSelectionMode = false;

  // List / Grid toggle — grid default on desktop, list default on Android
  bool _isGridView = !kIsWeb && defaultTargetPlatform != TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTreeAndCurrentLevel();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final hidden = _scrollController.hasClients && _scrollController.offset > 80;
    if (hidden != _isRootHidden) {
      setState(() => _isRootHidden = hidden);
    }
  }

  String get _currentRelPath => _navigationStack.last;

  FolderNode? get _currentNode {
    if (_rootTree == null) return null;
    if (_currentRelPath.isEmpty) return _rootTree;
    return _rootTree!.findByRelPath(_currentRelPath);
  }

  Future<void> _loadTreeAndCurrentLevel() async {
    setState(() => _isLoading = true);
    try {
      _rootTree = await _fileService.getFolderTree(widget.rootPath);
      await _loadImagesForCurrentNode();
    } catch (e) {
      debugPrint('Error loading folder tree: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadImagesForCurrentNode() async {
    final node = _currentNode;
    if (node == null) {
      _currentImages = [];
      return;
    }
    try {
      _currentImages =
          await _fileService.listImages(node.path, includeSubfolders: false);
    } catch (e) {
      debugPrint('Error loading images for node: $e');
      _currentImages = [];
    }
  }

  void _navigateToChild(FolderNode child) {
    setState(() {
      _navigationStack.add(child.relPath);
      _selectedImagePaths.clear();
      _isSelectionMode = false;
    });
    _loadImagesForCurrentNode().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _navigateBack() {
    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedImagePaths.clear();
      });
      return;
    }

    if (_navigationStack.length > 1) {
      setState(() {
        _navigationStack.removeLast();
        _selectedImagePaths.clear();
        _isSelectionMode = false;
      });
      _loadImagesForCurrentNode().then((_) {
        if (mounted) setState(() {});
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── Create folder ──────────────────────────────────────────────────────────

  Future<void> _showCreateFolderDialog() async {
    final sc = context.snapgroveColors;
    final controller = TextEditingController();

    final folderName = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                        .withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x22FFFFFF)
                          : const Color(0x18000000),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Folder',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        style: const TextStyle(
                            fontFamily: 'JetBrains Mono', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. Work, Receipts, Memes',
                          hintStyle: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              color: sc.muted),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel',
                                style:
                                    TextStyle(fontFamily: 'JetBrains Mono')),
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
                            child: const Text('Create',
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

    if (folderName != null && folderName.isNotEmpty && mounted) {
      final parentPath = _currentNode?.path ?? widget.rootPath;
      final success =
          await _fileService.createNestedFolder(parentPath, folderName);
      if (success) {
        _notificationService.showSnackBar('Folder "$folderName" created');
        await _loadTreeAndCurrentLevel();
      } else {
        _notificationService.showSnackBar('Failed to create folder',
            isError: true);
      }
    }
  }

  // ── Folder action dispatcher ───────────────────────────────────────────────

  void _onFolderAction(BuildContext context, FolderNode node, Offset? pos) {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid) {
      _showAndroidFolderBottomSheet(context, node);
    } else {
      _showDesktopContextMenu(context, node, pos ?? const Offset(200, 200));
    }
  }

  // ── Desktop context menu (anchored to mouse coordinates) ───────────────────

  Future<void> _showDesktopContextMenu(
      BuildContext context, FolderNode node, Offset position) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      elevation: 8,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: sc.border),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'rename',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.drive_file_rename_outline_rounded,
                  size: 18, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 10),
              const Text('Rename Folder',
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'properties',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 10),
              const Text('Folder Properties',
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'delete',
          height: 38,
          child: const Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Delete Folder',
                  style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
    );

    if (selected == 'rename') {
      _showRenameFolderDialog(node);
    } else if (selected == 'properties') {
      _showFolderInfoDialog(node);
    } else if (selected == 'delete') {
      _showDeleteFolderDialog(node);
    }
  }

  // ── Android symmetrical bottom sheet ───────────────────────────────────────

  Future<void> _showAndroidFolderBottomSheet(
      BuildContext context, FolderNode node) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 20 + MediaQuery.of(ctx).padding.bottom),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                    .withValues(alpha: 0.92),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border.all(
                  color: isDark
                      ? const Color(0x22FFFFFF)
                      : const Color(0x18000000),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sc.muted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Mini-header: folder name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_rounded, size: 18, color: sc.accent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          node.name,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 3 symmetrical icon actions: Rename, Properties, Delete
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BottomSheetActionItem(
                        icon: Icons.drive_file_rename_outline_rounded,
                        tooltip: 'Rename',
                        label: 'Rename',
                        color: isDark ? Colors.white : Colors.black87,
                        bgColor: sc.surfaceMuted,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showRenameFolderDialog(node);
                        },
                      ),
                      _BottomSheetActionItem(
                        icon: Icons.info_outline_rounded,
                        tooltip: 'Folder Properties',
                        label: 'Properties',
                        color: isDark ? Colors.white : Colors.black87,
                        bgColor: sc.surfaceMuted,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showFolderInfoDialog(node);
                        },
                      ),
                      _BottomSheetActionItem(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete Folder',
                        label: 'Delete',
                        color: const Color(0xFFEF4444),
                        bgColor:
                            const Color(0xFFEF4444).withValues(alpha: 0.12),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showDeleteFolderDialog(node);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Rename dialog ──────────────────────────────────────────────────────────

  Future<void> _showRenameFolderDialog(FolderNode node) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: node.name);

    final newName = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                        .withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x22FFFFFF)
                          : const Color(0x18000000),
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
                      const Text('Rename Folder',
                          style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
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
                                style:
                                    TextStyle(fontFamily: 'JetBrains Mono')),
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
                                style:
                                    TextStyle(fontFamily: 'JetBrains Mono')),
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

    if (newName != null &&
        newName.isNotEmpty &&
        newName != node.name &&
        mounted) {
      final ok = await _fileService.renameFolderNode(node.path, newName);
      if (ok) {
        _notificationService.showSnackBar('Renamed to "$newName"');
        await _loadTreeAndCurrentLevel();
      } else {
        _notificationService.showSnackBar('Failed to rename folder',
            isError: true);
      }
    }
  }

  // ── Folder Info / Properties dialog ────────────────────────────────────────

  Future<void> _showFolderInfoDialog(FolderNode node) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;

    String? modifiedStr;
    String? sizeStr;

    try {
      if (!kIsWeb && !node.path.startsWith('content://')) {
        final dir = Directory(node.path);
        final stat = await dir.stat();
        modifiedStr = _formatDateTime(stat.modified);
        int totalBytes = 0;
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              totalBytes += await entity.length();
            } catch (_) {}
          }
        }
        sizeStr = _formatBytes(totalBytes);
      }
    } catch (_) {}

    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                        .withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x22FFFFFF)
                          : const Color(0x18000000),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.folder_rounded,
                                color: Color(0xFFF59E0B), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Folder Properties',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: sc.muted,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  node.name,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                          height: 1,
                          color: isDark
                              ? const Color(0x1FFFFFFF)
                              : const Color(0x18000000)),
                      const SizedBox(height: 14),
                      _InfoRow(
                          label: 'Items',
                          value: '${node.totalImageCount}',
                          sc: sc),
                      const SizedBox(height: 8),
                      _InfoRow(
                          label: 'Subfolders',
                          value: '${node.children.length}',
                          sc: sc),
                      if (sizeStr != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Total Size', value: sizeStr, sc: sc),
                      ],
                      if (modifiedStr != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                            label: 'Modified', value: modifiedStr, sc: sc),
                      ],
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Path',
                        value: node.path,
                        sc: sc,
                        isMonospace: true,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Done',
                              style: TextStyle(fontFamily: 'JetBrains Mono')),
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
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale:
              Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      ),
    );
  }

  // ── Delete dialog ──────────────────────────────────────────────────────────

  Future<void> _showDeleteFolderDialog(FolderNode node) async {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                        .withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x22FFFFFF)
                          : const Color(0x18000000),
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
                      const Icon(Icons.delete_forever_rounded,
                          color: Color(0xFFEF4444), size: 36),
                      const SizedBox(height: 10),
                      Text(
                        'Delete "${node.name}"?',
                        style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you sure you want to permanently delete this folder and its contents?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 13,
                            color: sc.muted),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel',
                                style:
                                    TextStyle(fontFamily: 'JetBrains Mono')),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete',
                                style:
                                    TextStyle(fontFamily: 'JetBrains Mono')),
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

    if (confirmed == true && mounted) {
      final ok = await _fileService.deleteFolderNode(node.path);
      if (ok) {
        _notificationService.showSnackBar('Folder deleted');
        await _loadTreeAndCurrentLevel();
      } else {
        _notificationService.showSnackBar('Failed to delete folder',
            isError: true);
      }
    }
  }

  // ── Move images ────────────────────────────────────────────────────────────

  Future<void> _moveSelectedImages() async {
    if (_selectedImagePaths.isEmpty) return;

    final targetRelPath = await FolderTreePickerModal.show(
      context,
      rootNode: _rootTree,
      currentFolderName:
          _currentRelPath.isEmpty ? 'ROOT' : _currentRelPath,
      currentSelectedTags: [
        _currentRelPath.isEmpty ? 'ROOT' : _currentRelPath
      ],
    );

    if (targetRelPath != null && mounted) {
      final selectedList = _selectedImagePaths.toList();
      final success = await _fileService.moveFilesToFolder(
        widget.rootPath,
        targetRelPath,
        selectedList,
      );

      if (success) {
        _notificationService.showSnackBar(
            'Moved ${selectedList.length} image(s) to $targetRelPath');
        _selectedImagePaths.clear();
        _isSelectionMode = false;
        await _loadTreeAndCurrentLevel();
      } else {
        _notificationService.showSnackBar('Failed to move images',
            isError: true);
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDateTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}  ${pad(dt.hour)}:${pad(dt.minute)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isDesktop = !isAndroid && width >= 720;

    final currentNode = _currentNode;
    final isRoot = _currentRelPath.isEmpty;
    final childFolders = currentNode?.children ?? [];

    return PopScope(
      canPop: !_isSelectionMode && _navigationStack.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateBack();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: AppBar(
            backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/Back-Btn.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                    isDark ? Colors.white : Colors.black, BlendMode.srcIn),
              ),
              onPressed: _navigateBack,
            ),
            title: Text(
              _isSelectionMode
                  ? '${_selectedImagePaths.length} selected'
                  : (isRoot
                      ? 'Manage Folders'
                      : _currentRelPath.split('/').last),
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: _buildAppBarActions(
                context, sc, isDark, isDesktop, isAndroid, currentNode, width),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // ── Breadcrumbs ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: sc.surfaceMuted.withValues(alpha: 0.5),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                if (_navigationStack.length > 1) {
                                  setState(() {
                                    _navigationStack.removeRange(
                                        1, _navigationStack.length);
                                    _selectedImagePaths.clear();
                                    _isSelectionMode = false;
                                  });
                                  _loadImagesForCurrentNode().then((_) {
                                    if (mounted) setState(() {});
                                  });
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.home_outlined,
                                      size: 16, color: sc.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.rootTitle.isNotEmpty
                                        ? widget.rootTitle
                                        : 'ROOT',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 12,
                                      fontWeight: isRoot
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isRoot ? sc.accent : sc.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRoot) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right,
                                  size: 16, color: sc.muted),
                              const SizedBox(width: 6),
                              Text(
                                _currentRelPath.replaceAll('/', ' > '),
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: sc.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Root special card (only at root level) ───────────────
                  if (isRoot)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Text(
                          'ROOT FOLDER',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: sc.muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),

                  if (isRoot && currentNode != null)
                    SliverToBoxAdapter(
                      child: _buildRootCard(
                          context, sc, isDark, currentNode, width),
                    ),

                  // ── Sticky subfolders section header with blur ───────────
                  if (childFolders.isNotEmpty)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyFolderHeaderDelegate(
                        title: isRoot ? 'FOLDERS' : 'SUBFOLDERS',
                        folderCount: childFolders.length,
                        isGridView: _isGridView,
                        onToggleView: () =>
                            setState(() => _isGridView = !_isGridView),
                        isRoot: isRoot,
                        isRootHidden: _isRootHidden,
                        rootItemCount: _rootTree?.totalImageCount ?? 0,
                        rootFolderCount: _rootTree?.children.length ?? 0,
                        sc: sc,
                        isDark: isDark,
                      ),
                    ),

                  // ── Folder list / grid ──────────────────────────────────
                  if (childFolders.isNotEmpty)
                    _isGridView
                        ? _buildFolderGrid(context, sc, isDark, childFolders,
                            isAndroid, width)
                        : _buildFolderList(
                            context, sc, isDark, childFolders, isAndroid),

                  // ── Images section ──────────────────────────────────────
                  if (!isRoot) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'IMAGES IN THIS FOLDER (${_currentImages.length})',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sc.muted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (_currentImages.isNotEmpty && !_isSelectionMode)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isSelectionMode = true;
                                  });
                                },
                                child: Text(
                                  'Select',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: sc.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_currentImages.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No images directly in this folder',
                              style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 13,
                                  color: sc.muted),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.85,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildImageTile(context, sc, index),
                            childCount: _currentImages.length,
                          ),
                        ),
                      ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
        bottomNavigationBar: _isSelectionMode
            ? Container(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  border: Border(top: BorderSide(color: sc.border)),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _selectedImagePaths.isNotEmpty
                      ? _moveSelectedImages
                      : null,
                  icon: const Icon(Icons.drive_file_move_outlined, size: 20),
                  label: Text(
                    'Move (${_selectedImagePaths.length}) to Folder...',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // ── AppBar actions ─────────────────────────────────────────────────────────

  List<Widget> _buildAppBarActions(
    BuildContext context,
    dynamic sc,
    bool isDark,
    bool isDesktop,
    bool isAndroid,
    FolderNode? currentNode,
    double width,
  ) {
    final isRoot = _currentRelPath.isEmpty;

    // 1. Selection mode
    if (_isSelectionMode) {
      if (isDesktop) {
        // Larger display: direct inline buttons without more_vert
        return [
          TextButton(
            onPressed: () {
              setState(() => _selectedImagePaths.addAll(_currentImages));
            },
            child: Text(
              'Select all',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sc.accent,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _selectedImagePaths.clear());
            },
            child: Text(
              'Unselect all',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: sc.muted,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isSelectionMode = false;
                _selectedImagePaths.clear();
              });
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: sc.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ];
      } else {
        // Mobile in selection mode: keep more_vert with items
        return [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            tooltip: 'Selection options',
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: sc.border),
            ),
            onSelected: (value) {
              switch (value) {
                case 'select_all':
                  setState(() => _selectedImagePaths.addAll(_currentImages));
                  break;
                case 'unselect_all':
                  setState(() => _selectedImagePaths.clear());
                  break;
                case 'cancel_select':
                  setState(() {
                    _isSelectionMode = false;
                    _selectedImagePaths.clear();
                  });
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'select_all',
                height: 40,
                child: Text('Select all',
                    style:
                        TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13)),
              ),
              const PopupMenuItem<String>(
                value: 'unselect_all',
                height: 40,
                child: Text('Unselect all',
                    style:
                        TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13)),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem<String>(
                value: 'cancel_select',
                height: 40,
                child: Text('Cancel select',
                    style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                        color: Color(0xFFEF4444))),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ];
      }
    }

    // 2. Normal mode at ROOT: remove more/view
    if (isRoot) {
      return [
        IconButton(
          tooltip: 'New Folder',
          icon: const Icon(Icons.create_new_folder_outlined, size: 22),
          onPressed: _showCreateFolderDialog,
        ),
        const SizedBox(width: 6),
      ];
    }

    // 3. Normal mode inside SUBFOLDER: keep more_vert on mobile
    if (isDesktop) {
      return [
        if (_currentImages.isNotEmpty)
          IconButton(
            tooltip: 'Select Images',
            icon: const Icon(Icons.checklist, size: 22),
            onPressed: () => setState(() => _isSelectionMode = true),
          ),
        IconButton(
          tooltip: 'New Folder',
          icon: const Icon(Icons.create_new_folder_outlined, size: 22),
          onPressed: _showCreateFolderDialog,
        ),
        const SizedBox(width: 8),
      ];
    } else {
      return [
        IconButton(
          tooltip: 'New Folder',
          icon: const Icon(Icons.create_new_folder_outlined, size: 22),
          onPressed: _showCreateFolderDialog,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 22),
          tooltip: 'More',
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: sc.border),
          ),
          onSelected: (value) {
            if (value == 'select') {
              setState(() => _isSelectionMode = true);
            }
          },
          itemBuilder: (_) => [
            if (_currentImages.isNotEmpty)
              const PopupMenuItem<String>(
                value: 'select',
                height: 42,
                child: Row(
                  children: [
                    Icon(Icons.checklist, size: 18),
                    SizedBox(width: 10),
                    Text('Select Images',
                        style: TextStyle(
                            fontFamily: 'JetBrains Mono', fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ];
    }
  }

  // ── Root special card ──────────────────────────────────────────────────────

  Widget _buildRootCard(
    BuildContext context,
    dynamic sc,
    bool isDark,
    FolderNode node,
    double width,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: sc.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.folder_special_rounded,
              color: Color(0xFFF59E0B), size: 22),
        ),
        title: Text(
          widget.rootTitle.isNotEmpty ? widget.rootTitle : 'Root Folder',
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: width >= 340
            ? Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${node.totalImageCount}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' items  •  '),
                  TextSpan(
                    text: '${node.children.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' folders'),
                ]),
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: sc.muted,
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'ROOT',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF59E0B),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Folder list (compact mobile view) ──────────────────────────────────────

  Widget _buildFolderList(
    BuildContext context,
    dynamic sc,
    bool isDark,
    List<FolderNode> folders,
    bool isAndroid,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final child = folders[index];
          return LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            return GestureDetector(
              onLongPress: isAndroid
                  ? () => _onFolderAction(context, child, null)
                  : null,
              onSecondaryTapUp: !isAndroid
                  ? (details) =>
                      _onFolderAction(context, child, details.globalPosition)
                  : null,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: sc.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sc.border),
                ),
                child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: sc.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      child.hasChildren
                          ? Icons.folder_rounded
                          : Icons.folder_outlined,
                      color: sc.accent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    child.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: w >= 340
                      ? Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '${child.totalImageCount}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' items  •  '),
                            TextSpan(
                              text: '${child.children.length}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' folders'),
                          ]),
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: sc.muted,
                          ),
                        )
                      : null,
                  onTap: () => _navigateToChild(child),
                ),
              ),
            );
          });
        },
        childCount: folders.length,
      ),
    );
  }

  // ── Folder grid (desktop-style icon layout without square cards) ───────────

  Widget _buildFolderGrid(
    BuildContext context,
    dynamic sc,
    bool isDark,
    List<FolderNode> folders,
    bool isAndroid,
    double width,
  ) {
    final crossAxisCount = width < 360
        ? 3
        : width < 540
            ? 4
            : width < 800
                ? 5
                : width < 1100
                    ? 6
                    : 8;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          mainAxisExtent: 112,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final child = folders[index];
            return _FolderGridCard(
              node: child,
              sc: sc,
              isDark: isDark,
              isAndroid: isAndroid,
              onTap: () => _navigateToChild(child),
              onAction: (pos) => _onFolderAction(context, child, pos),
            );
          },
          childCount: folders.length,
        ),
      ),
    );
  }

  // ── Image tile ─────────────────────────────────────────────────────────────

  Widget _buildImageTile(BuildContext context, dynamic sc, int index) {
    final imgPath = _currentImages[index];
    final isSelected = _selectedImagePaths.contains(imgPath);

    return InkWell(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedImagePaths.remove(imgPath);
              if (_selectedImagePaths.isEmpty) _isSelectionMode = false;
            } else {
              _selectedImagePaths.add(imgPath);
            }
          });
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImagePreviewView(
                files: _currentImages,
                initialIndex: index,
                directoryPath: widget.rootPath,
                subfolders:
                    _rootTree?.children.map((c) => c.relPath).toList(),
              ),
            ),
          );
        }
      },
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedImagePaths.add(imgPath);
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: _thumbnailManager.getThumbnail(imgPath),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                }
                return Container(color: sc.surfaceMuted);
              },
            ),
            if (_isSelectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? sc.accent
                        : Colors.black.withValues(alpha: 0.4),
                    border:
                        Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sticky persistent header for FOLDERS section (with blur & sticky ROOT badge)
// ─────────────────────────────────────────────────────────────────────────────

class _StickyFolderHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int folderCount;
  final bool isGridView;
  final VoidCallback onToggleView;
  final bool isRoot;
  final bool isRootHidden;
  final int rootItemCount;
  final int rootFolderCount;
  final dynamic sc;
  final bool isDark;

  _StickyFolderHeaderDelegate({
    required this.title,
    required this.folderCount,
    required this.isGridView,
    required this.onToggleView,
    required this.isRoot,
    required this.isRootHidden,
    required this.rootItemCount,
    required this.rootFolderCount,
    required this.sc,
    required this.isDark,
  });

  @override
  double get minExtent => 44.0;

  @override
  double get maxExtent => 44.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF141414) : Colors.white)
                .withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: overlapsContent ? sc.border : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$title ($folderCount)',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sc.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (isRoot && isRootHidden) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message:
                          '$rootItemCount items • $rootFolderCount folders',
                      triggerMode: TooltipTriggerMode.tap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_special_rounded,
                                size: 11, color: Color(0xFFF59E0B)),
                            SizedBox(width: 3),
                            Text(
                              'ROOT',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // List / Grid toggle
              GestureDetector(
                onTap: onToggleView,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sc.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sc.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        size: 15,
                        color: sc.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isGridView ? 'List' : 'Grid',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sc.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFolderHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.folderCount != folderCount ||
        oldDelegate.isGridView != isGridView ||
        oldDelegate.isRoot != isRoot ||
        oldDelegate.isRootHidden != isRootHidden ||
        oldDelegate.rootItemCount != rootItemCount ||
        oldDelegate.rootFolderCount != rootFolderCount ||
        oldDelegate.isDark != isDark;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Desktop-style Folder Grid Card (no outer square box, prominent icon glyph)
// ─────────────────────────────────────────────────────────────────────────────

class _FolderGridCard extends StatefulWidget {
  final FolderNode node;
  final dynamic sc;
  final bool isDark;
  final bool isAndroid;
  final VoidCallback onTap;
  final void Function(Offset?) onAction;

  const _FolderGridCard({
    required this.node,
    required this.sc,
    required this.isDark,
    required this.isAndroid,
    required this.onTap,
    required this.onAction,
  });

  @override
  State<_FolderGridCard> createState() => _FolderGridCardState();
}

class _FolderGridCardState extends State<_FolderGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final node = widget.node;
    final isHover = _hovered && !widget.isAndroid;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onLongPress: widget.isAndroid ? () => widget.onAction(null) : null,
        onSecondaryTapUp: !widget.isAndroid
            ? (details) => widget.onAction(details.globalPosition)
            : null,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Squircle icon container (prominent glowing glyph)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: isHover
                      ? sc.accent.withValues(alpha: 0.24)
                      : sc.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHover
                        ? sc.accent.withValues(alpha: 0.45)
                        : sc.accent.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                  boxShadow: isHover
                      ? [
                          BoxShadow(
                            color: sc.accent.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    node.hasChildren
                        ? Icons.folder_rounded
                        : Icons.folder_outlined,
                    color: sc.accent,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Folder label underneath
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  node.name,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Android bottom sheet symmetrical action item
// ─────────────────────────────────────────────────────────────────────────────

class _BottomSheetActionItem extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _BottomSheetActionItem({
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Info row (used in folder properties dialog)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final dynamic sc;
  final bool isMonospace;
  final int maxLines;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.sc,
    this.isMonospace = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: sc.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: isMonospace ? 'JetBrains Mono' : 'Lora',
              fontSize: isMonospace ? 11 : 13,
              color: null,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
