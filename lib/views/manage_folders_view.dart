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

  bool _isLoading = true;
  FolderNode? _rootTree;

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
    _loadTreeAndCurrentLevel();
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

  // ── Frosted action menu (right-click / long-press) ─────────────────────────

  Future<void> _showFolderActionMenu(
      BuildContext context, FolderNode node, Offset? tapPosition) async {
    // Show frosted blurred popup card
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
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
                  width: 280,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Folder name header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        child: Text(
                          node.name,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white70
                                : Colors.black.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0x1FFFFFFF)
                            : const Color(0x18000000),
                      ),
                      const SizedBox(height: 4),
                      // Rename
                      _FrostedActionTile(
                        icon: Icons.drive_file_rename_outline_rounded,
                        label: 'Rename Folder',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showRenameFolderDialog(node);
                        },
                      ),
                      // Info
                      _FrostedActionTile(
                        icon: Icons.info_outline_rounded,
                        label: 'Folder Info / Properties',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showFolderInfoDialog(node);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 6),
                        child: Divider(
                          height: 1,
                          color: isDark
                              ? const Color(0x1FFFFFFF)
                              : const Color(0x18000000),
                        ),
                      ),
                      // Delete (destructive)
                      _FrostedActionTile(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete Folder',
                        isDestructive: true,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showDeleteFolderDialog(node);
                        },
                      ),
                      const SizedBox(height: 4),
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
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
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

  // ── Folder Info dialog ─────────────────────────────────────────────────────

  Future<void> _showFolderInfoDialog(FolderNode node) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;

    // Gather info (best-effort on each platform)
    String? modifiedStr;
    String? sizeStr;

    try {
      if (!kIsWeb && !node.path.startsWith('content://')) {
        final dir = Directory(node.path);
        final stat = await dir.stat();
        modifiedStr = _formatDateTime(stat.modified);
        // size: sum all files
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.folder_rounded,
                                color: Color(0xFFF59E0B), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              node.name,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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

    // On root we show a special "ROOT" card + all child folders
    // On sub-levels we show child folders only
    final childFolders = currentNode?.children ?? [];

    return Scaffold(
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
            isRoot
                ? 'Manage Folders'
                : _currentRelPath.split('/').last,
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
              slivers: [
                // ── Breadcrumbs ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            Icon(Icons.chevron_right, size: 16, color: sc.muted),
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
                    child: _buildRootCard(context, sc, isDark, currentNode, width),
                  ),

                // ── Subfolders section header ─────────────────────────────
                if (childFolders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isRoot
                                ? 'FOLDERS (${childFolders.length})'
                                : 'SUBFOLDERS (${childFolders.length})',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sc.muted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          // List/Grid toggle
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isGridView = !_isGridView),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: sc.surfaceMuted,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: sc.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isGridView
                                        ? Icons.view_list_rounded
                                        : Icons.grid_view_rounded,
                                    size: 15,
                                    color: sc.muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isGridView ? 'List' : 'Grid',
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

                // ── Folder list / grid ────────────────────────────────────
                if (childFolders.isNotEmpty)
                  _isGridView
                      ? _buildFolderGrid(
                          context, sc, isDark, childFolders, isAndroid, width)
                      : _buildFolderList(
                          context, sc, isDark, childFolders, isAndroid),

                // ── Images section ────────────────────────────────────────
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
                onPressed:
                    _selectedImagePaths.isNotEmpty ? _moveSelectedImages : null,
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
    if (_isSelectionMode) {
      // Selection mode: show Select All / Deselect All
      return [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedImagePaths.addAll(_currentImages);
            });
          },
          child: Text(
            'All',
            style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: sc.accent,
                fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedImagePaths.clear();
              _isSelectionMode = false;
            });
          },
          child: Text(
            'None',
            style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: sc.muted,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 4),
      ];
    }

    // Normal mode
    if (isDesktop) {
      // Desktop / tablet: show actions inline
      return [
        // List/Grid toggle inline on desktop too
        IconButton(
          tooltip: _isGridView ? 'List view' : 'Grid view',
          icon: Icon(
              _isGridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              size: 22),
          onPressed: () => setState(() => _isGridView = !_isGridView),
        ),
        if (_currentRelPath.isNotEmpty && _currentImages.isNotEmpty)
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
      // Mobile: More menu collapses view toggle and select
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
            switch (value) {
              case 'toggle_view':
                setState(() => _isGridView = !_isGridView);
                break;
              case 'select':
                setState(() => _isSelectionMode = true);
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              value: 'toggle_view',
              height: 42,
              child: Row(
                children: [
                  Icon(
                    _isGridView
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isGridView ? 'View: List' : 'View: Grid',
                    style: const TextStyle(
                        fontFamily: 'JetBrains Mono', fontSize: 13),
                  ),
                ],
              ),
            ),
            if (_currentRelPath.isNotEmpty && _currentImages.isNotEmpty)
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
                  TextSpan(text: ' items  •  '),
                  TextSpan(
                    text: '${node.children.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' folders'),
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
          child: Text(
            'SYSTEM',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Folder list (default mobile) ───────────────────────────────────────────

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
                  ? () => _showFolderActionMenu(context, child, null)
                  : null,
              onSecondaryTapUp: !isAndroid
                  ? (details) => _showFolderActionMenu(
                      context, child, details.globalPosition)
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
                  trailing: null, // removed ugly more_vert
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

  // ── Folder grid ────────────────────────────────────────────────────────────

  Widget _buildFolderGrid(
    BuildContext context,
    dynamic sc,
    bool isDark,
    List<FolderNode> folders,
    bool isAndroid,
    double width,
  ) {
    final crossAxisCount = width < 400
        ? 2
        : width < 700
            ? 3
            : width < 1000
                ? 4
                : 5;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
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
              onAction: (pos) =>
                  _showFolderActionMenu(context, child, pos),
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
//  Folder Grid Card  (hover shows subtitle on desktop, clean on mobile)
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
    final showHoverInfo = _hovered && !widget.isAndroid;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onLongPress: widget.isAndroid
            ? () => widget.onAction(null)
            : null,
        onSecondaryTapUp: !widget.isAndroid
            ? (details) => widget.onAction(details.globalPosition)
            : null,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _hovered
                  ? sc.surfaceElevated
                  : sc.surfaceMuted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered ? sc.accent.withValues(alpha: 0.3) : sc.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: sc.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      node.hasChildren
                          ? Icons.folder_rounded
                          : Icons.folder_outlined,
                      color: sc.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    node.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  // Subtitle only on hover (desktop) — hidden on mobile
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: showHoverInfo ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '${node.totalImageCount}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' items'),
                        ]),
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          color: sc.muted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Frosted action tile (used in action menu)
// ─────────────────────────────────────────────────────────────────────────────

class _FrostedActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _FrostedActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_FrostedActionTile> createState() => _FrostedActionTileState();
}

class _FrostedActionTileState extends State<_FrostedActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.isDestructive
        ? const Color(0xFFEF4444)
        : (isDark ? Colors.white : Colors.black);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.isDestructive
                    ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                    : sc.menuHover)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
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
//  Info row (used in folder info dialog)
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
