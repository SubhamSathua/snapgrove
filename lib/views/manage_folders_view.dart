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
      // In SAF, node.path is the specific directory URI
      _currentImages = await _fileService.listImages(node.path, includeSubfolders: false);
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
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: sc.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sc.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Tag / Folder',
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
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Work, Receipts, Memes',
                      hintStyle: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: sc.muted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel', style: TextStyle(fontFamily: 'JetBrains Mono')),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                        child: const Text('Create', style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (folderName != null && folderName.isNotEmpty && mounted) {
      final parentPath = _currentNode?.path ?? widget.rootPath;
      final success = await _fileService.createNestedFolder(parentPath, folderName);
      if (success) {
        _notificationService.showSnackBar('Folder "$folderName" created');
        await _loadTreeAndCurrentLevel();
      } else {
        _notificationService.showSnackBar('Failed to create folder', isError: true);
      }
    }
  }

  Future<void> _showEditFolderDialog(FolderNode node) async {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: node.name);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage "${node.name}"',
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename Tag / Folder', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14)),
                onTap: () => Navigator.of(ctx).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Delete Tag / Folder', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, color: Color(0xFFEF4444))),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'rename' && mounted) {
      final newName = await showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black.withValues(alpha: 0.5),
        pageBuilder: (ctx, anim1, anim2) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: sc.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sc.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rename Folder', style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel', style: TextStyle(fontFamily: 'JetBrains Mono')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                          child: const Text('Save', style: TextStyle(fontFamily: 'JetBrains Mono')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (newName != null && newName.isNotEmpty && newName != node.name && mounted) {
        final ok = await _fileService.renameFolderNode(node.path, newName);
        if (ok) {
          _notificationService.showSnackBar('Renamed to "$newName"');
          await _loadTreeAndCurrentLevel();
        } else {
          _notificationService.showSnackBar('Failed to rename folder', isError: true);
        }
      }
    } else if (action == 'delete' && mounted) {
      final confirmed = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black.withValues(alpha: 0.5),
        pageBuilder: (ctx, anim1, anim2) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: sc.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sc.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 36),
                    const SizedBox(height: 10),
                    Text(
                      'Delete "${node.name}"?',
                      style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Are you sure you want to permanently delete this folder and its contents?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Lora', fontSize: 13, color: sc.muted),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel', style: TextStyle(fontFamily: 'JetBrains Mono')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Delete', style: TextStyle(fontFamily: 'JetBrains Mono')),
                        ),
                      ],
                    ),
                  ],
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
          _notificationService.showSnackBar('Failed to delete folder', isError: true);
        }
      }
    }
  }

  Future<void> _moveSelectedImages() async {
    if (_selectedImagePaths.isEmpty) return;

    final targetRelPath = await FolderTreePickerModal.show(
      context,
      rootNode: _rootTree,
      currentFolderName: _currentRelPath.isEmpty ? 'ROOT' : _currentRelPath,
      currentSelectedTags: [_currentRelPath.isEmpty ? 'ROOT' : _currentRelPath],
    );

    if (targetRelPath != null && mounted) {
      final selectedList = _selectedImagePaths.toList();
      final success = await _fileService.moveFilesToFolder(
        widget.rootPath,
        targetRelPath,
        selectedList,
      );

      if (success) {
        _notificationService.showSnackBar('Moved ${selectedList.length} image(s) to $targetRelPath');
        _selectedImagePaths.clear();
        _isSelectionMode = false;
        await _loadTreeAndCurrentLevel();
      } else {
        _notificationService.showSnackBar('Failed to move images', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentNode = _currentNode;
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
              colorFilter: ColorFilter.mode(isDark ? Colors.white : Colors.black, BlendMode.srcIn),
            ),
            onPressed: _navigateBack,
          ),
          title: Text(
            _currentRelPath.isEmpty ? 'Manage Tags' : _currentRelPath.split('/').last,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (!_isSelectionMode) ...[
              IconButton(
                tooltip: 'New Folder',
                icon: const Icon(Icons.create_new_folder_outlined, size: 22),
                onPressed: _showCreateFolderDialog,
              ),
              if (_currentImages.isNotEmpty)
                IconButton(
                  tooltip: 'Select Images',
                  icon: const Icon(Icons.checklist, size: 22),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedImagePaths.addAll(_currentImages);
                    });
                  },
                ),
            ] else ...[
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedImagePaths.length == _currentImages.length) {
                      _selectedImagePaths.clear();
                      _isSelectionMode = false;
                    } else {
                      _selectedImagePaths.addAll(_currentImages);
                    }
                  });
                },
                child: Text(
                  _selectedImagePaths.length == _currentImages.length ? 'Deselect All' : 'Select All',
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: sc.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : CustomScrollView(
              slivers: [
                // Breadcrumbs Header
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: sc.surfaceMuted.withValues(alpha: 0.5),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (_navigationStack.length > 1) {
                                setState(() {
                                  _navigationStack.removeRange(1, _navigationStack.length);
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
                                Icon(Icons.home_outlined, size: 16, color: sc.accent),
                                const SizedBox(width: 4),
                                Text(
                                  widget.rootTitle.isNotEmpty ? widget.rootTitle : 'ROOT',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 12,
                                    fontWeight: _currentRelPath.isEmpty ? FontWeight.w700 : FontWeight.w500,
                                    color: _currentRelPath.isEmpty ? sc.accent : sc.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_currentRelPath.isNotEmpty) ...[
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

                // Folder List Section Header
                if (childFolders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(
                        'SUBFOLDERS (${childFolders.length})',
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

                // Folder List
                if (childFolders.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final child = childFolders[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                child.hasChildren ? Icons.folder : Icons.folder_outlined,
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
                            subtitle: Text(
                              '${child.directImageCount} direct • ${child.totalImageCount} total • ${child.children.length} subfolders',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                color: sc.muted,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onPressed: () => _showEditFolderDialog(child),
                            ),
                            onTap: () => _navigateToChild(child),
                          ),
                        );
                      },
                      childCount: childFolders.length,
                    ),
                  ),

                // Images Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'IMAGES IN THIS TAG (${_currentImages.length})',
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

                // Images Grid
                if (_currentImages.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No images directly in this folder',
                          style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: sc.muted),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
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
                                      subfolders: _rootTree?.children.map((c) => c.relPath).toList(),
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
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                        );
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
                                          color: isSelected ? sc.accent : Colors.black.withValues(alpha: 0.4),
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                                            : null,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _currentImages.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                border: Border(top: BorderSide(color: sc.border)),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: _selectedImagePaths.isNotEmpty ? _moveSelectedImages : null,
                icon: const Icon(Icons.drive_file_move_outlined, size: 20),
                label: Text(
                  'Move (${_selectedImagePaths.length}) to Tag...',
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
}
