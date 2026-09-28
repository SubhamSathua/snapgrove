import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/locator.dart';
import '../services/bin_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/bin_view_model.dart';
import 'bin_preview_view.dart';

class BinView extends StatefulWidget {
  final String? targetDirectory;

  const BinView({
    super.key,
    this.targetDirectory,
  });

  @override
  State<BinView> createState() => _BinViewState();
}

class _BinViewState extends State<BinView> {
  late BinViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = locator<BinViewModel>();
    _viewModel.loadFolders();
  }

  Future<void> _confirmEmptyFullBin() async {
    final sc = context.snapgroveColors;
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.9 > 380 ? 380 : MediaQuery.of(ctx).size.width * 0.9,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: sc.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sc.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
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
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Empty Full Bin',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Are you sure you want to permanently delete ALL files in the bin? This cannot be undone.',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      color: sc.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogBtn(
                        label: 'Cancel',
                        isPrimary: false,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 10),
                      _DialogBtn(
                        label: 'Empty Bin',
                        isPrimary: true,
                        isDestructive: true,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
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

    if (confirmed == true) {
      await _viewModel.emptyFullBin();
    }
  }

  Future<void> _confirmEmptyFolder() async {
    final sc = context.snapgroveColors;
    final folderName = _viewModel.currentFolder ?? '';
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.9 > 380 ? 380 : MediaQuery.of(ctx).size.width * 0.9,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: sc.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sc.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
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
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Empty Folder',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Are you sure you want to permanently delete all items in "$folderName"?',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      color: sc.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogBtn(
                        label: 'Cancel',
                        isPrimary: false,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 10),
                      _DialogBtn(
                        label: 'Empty Folder',
                        isPrimary: true,
                        isDestructive: true,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
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

    if (confirmed == true) {
      await _viewModel.emptyCurrentFolder();
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final sc = context.snapgroveColors;
    final count = _viewModel.selectedCount;
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.9 > 380 ? 380 : MediaQuery.of(ctx).size.width * 0.9,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: sc.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sc.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
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
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Permanently Delete',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Permanently delete $count selected item${count == 1 ? '' : 's'}? This action cannot be undone.',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      color: sc.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogBtn(
                        label: 'Cancel',
                        isPrimary: false,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 10),
                      _DialogBtn(
                        label: 'Delete',
                        isPrimary: true,
                        isDestructive: true,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
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

    if (confirmed == true) {
      await _viewModel.deleteSelectedFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final isRoot = _viewModel.currentFolder == null;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: AppBar(
              backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/Back-Btn.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(isDark ? Colors.white : Colors.black, BlendMode.srcIn),
                ),
                onPressed: () {
                  if (_viewModel.isSelectionMode) {
                    _viewModel.clearSelection();
                  } else if (!isRoot) {
                    _viewModel.loadFolders();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: Text(
                _viewModel.isSelectionMode
                    ? '${_viewModel.selectedCount} Selected'
                    : (isRoot ? 'Bin' : _viewModel.currentFolder!),
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                if (isRoot) ...[
                  if (_viewModel.folders.isNotEmpty && _viewModel.totalItemsInAllFolders > 0)
                    TextButton.icon(
                      onPressed: _confirmEmptyFullBin,
                      icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 20),
                      label: const Text(
                        'Empty Bin',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                ] else ...[
                  if (!_viewModel.isSelectionMode && _viewModel.files.isNotEmpty) ...[
                    IconButton(
                      tooltip: 'Select',
                      icon: const Icon(Icons.checklist, size: 22),
                      onPressed: () => _viewModel.selectAll(),
                    ),
                    TextButton.icon(
                      onPressed: _confirmEmptyFolder,
                      icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 18),
                      label: const Text(
                        'Empty Folder',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                  if (_viewModel.isSelectionMode)
                    TextButton(
                      onPressed: () {
                        if (_viewModel.isAllSelected) {
                          _viewModel.clearSelection();
                        } else {
                          _viewModel.selectAll();
                        }
                      },
                      child: Text(
                        _viewModel.isAllSelected ? 'Deselect All' : 'Select All',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sc.accent,
                        ),
                      ),
                    ),
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
          body: _viewModel.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFff2a7b), strokeWidth: 2),
                )
              : (isRoot ? _buildFoldersList() : _buildFilesGrid()),
          bottomNavigationBar: _viewModel.isSelectionMode && !isRoot
              ? _buildSelectionBottomBar()
              : null,
        );
      },
    );
  }

  Widget _buildFoldersList() {
    final sc = context.snapgroveColors;
    final folders = _viewModel.folders;

    if (folders.isEmpty || _viewModel.totalItemsInAllFolders == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: sc.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/trash.svg',
                    width: 32,
                    height: 32,
                    colorFilter: ColorFilter.mode(sc.muted, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bin is empty',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Items moved to the bin are encrypted and safely stored for 30 days before permanent deletion.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 14,
                  color: sc.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: folders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final folder = folders[index];
        return _FolderCard(
          folder: folder,
          onTap: () => _viewModel.openFolder(folder.name),
        );
      },
    );
  }

  Widget _buildFilesGrid() {
    final sc = context.snapgroveColors;
    final files = _viewModel.files;

    if (files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined, size: 56, color: sc.muted),
              const SizedBox(height: 16),
              Text(
                'Folder is empty',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: sc.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 5 : (width > 600 ? 4 : 3);

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSelected = _viewModel.selectedFilePaths.contains(file.path);

        return _BinThumbnailTile(
          file: file,
          isSelected: isSelected,
          isSelectionMode: _viewModel.isSelectionMode,
          onTap: () {
            if (_viewModel.isSelectionMode) {
              _viewModel.toggleSelection(file.path);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BinPreviewView(
                    viewModel: _viewModel,
                    initialIndex: index,
                    targetDirectory: widget.targetDirectory,
                  ),
                ),
              );
            }
          },
          onLongPress: () {
            _viewModel.toggleSelection(file.path);
          },
        );
      },
    );
  }

  Widget _buildSelectionBottomBar() {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: sc.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Delete Permanently
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _viewModel.selectedCount > 0 ? _confirmDeleteSelected : null,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text(
                  'Delete Permanently',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Restore Selected
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _viewModel.selectedCount > 0
                    ? () => _viewModel.restoreSelectedFiles(targetDirectory: widget.targetDirectory)
                    : null,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text(
                  'Restore',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2fad5c),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF2fad5c).withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final BinFolderInfo folder;
  final VoidCallback onTap;

  const _FolderCard({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: sc.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sc.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFff2a7b).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.folder_outlined, color: Color(0xFFff2a7b), size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${folder.itemCount} item${folder.itemCount == 1 ? '' : 's'} • ${folder.formattedSize}',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          color: sc.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: sc.muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BinThumbnailTile extends StatefulWidget {
  final BinFileInfo file;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BinThumbnailTile({
    required this.file,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_BinThumbnailTile> createState() => _BinThumbnailTileState();
}

class _BinThumbnailTileState extends State<_BinThumbnailTile> {
  Uint8List? _decryptedBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  Future<void> _loadBytes() async {
    try {
      final bytes = await locator<BinService>().readDecryptedFile(widget.file.path);
      if (mounted) {
        setState(() {
          _decryptedBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final days = widget.file.daysRemaining;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          Container(
            color: sc.surfaceMuted,
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Color(0xFFff2a7b), strokeWidth: 2),
                    ),
                  )
                : (_decryptedBytes != null
                    ? Image.memory(
                        _decryptedBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) =>
                            const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 28)),
                      )
                    : const Center(child: Icon(Icons.image, color: Colors.white38, size: 28))),
          ),

          // Days remaining badge
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${days}d',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: days <= 5 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ),
          ),

          // Selection indicator checkbox
          if (widget.isSelectionMode)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected ? const Color(0xFFff2a7b) : Colors.black45,
                  border: Border.all(
                    color: widget.isSelected ? Colors.transparent : Colors.white,
                    width: 1.5,
                  ),
                ),
                child: widget.isSelected
                    ? const Center(child: Icon(Icons.check, size: 14, color: Colors.black))
                    : null,
              ),
            ),

          // Selection overlay border
          if (widget.isSelected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFff2a7b), width: 2.5),
              ),
            ),

          // Touch inkwell
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DialogBtn({
    required this.label,
    required this.isPrimary,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final Color bgColor = isPrimary
        ? (isDestructive ? const Color(0xFFEF4444) : const Color(0xFFff2a7b))
        : Colors.transparent;
    final Color fgColor = isPrimary
        ? Colors.white
        : (isDestructive ? const Color(0xFFEF4444) : sc.muted);

    return Container(
      constraints: const BoxConstraints(minWidth: 90, minHeight: 38),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: !isPrimary ? Border.all(color: sc.border) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
