import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/locator.dart';
import '../services/bin_service.dart';
import '../theme/app_theme.dart';
import '../theme/snap_symbols.dart';
import '../viewmodels/app_view_model.dart';
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
    _viewModel.loadBin();
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
                          child: Icon(SnapSymbols.delete_forever, color: Color(0xFFEF4444), size: 22),
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
                          child: Icon(SnapSymbols.delete_outline, color: Color(0xFFEF4444), size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete $count ${count == 1 ? "Item" : "Items"}?',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Are you sure you want to permanently delete $count ${count == 1 ? "file" : "files"}? This action cannot be undone.',
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
                        label: 'Delete Permanently',
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

  Future<void> _restoreSelected() async {
    String? target = widget.targetDirectory;
    if (target == null || target.isEmpty) {
      if (locator.isRegistered<AppViewModel>()) {
        final appVm = locator<AppViewModel>();
        target = appVm.screenshotDir ?? appVm.permanentScreenshotDir;
      }
    }
    await _viewModel.restoreSelectedFiles(targetDirectory: target);
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
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
                onPressed: _viewModel.isRestoring
                    ? null
                    : () {
                        if (_viewModel.isSelectionMode) {
                          _viewModel.clearSelection();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _viewModel.isSelectionMode
                        ? '${_viewModel.selectedCount} Selected'
                        : 'Bin',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!_viewModel.isSelectionMode && _viewModel.allFiles.isNotEmpty)
                    Text(
                      '${_viewModel.allFiles.length} item${_viewModel.allFiles.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: sc.muted,
                      ),
                    ),
                ],
              ),
              actions: [
                if (!_viewModel.isSelectionMode) ...[
                  if (_viewModel.allFiles.isNotEmpty) ...[
                    IconButton(
                      tooltip: 'Select',
                      icon: const Icon(SnapSymbols.checklist, size: 22),
                      onPressed: _viewModel.isRestoring ? null : () => _viewModel.selectAll(),
                    ),
                    TextButton.icon(
                      onPressed: _viewModel.isRestoring ? null : _confirmEmptyFullBin,
                      icon: const Icon(SnapSymbols.delete_sweep_outlined, color: Color(0xFFEF4444), size: 18),
                      label: const Text(
                        'Empty Bin',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  TextButton(
                    onPressed: _viewModel.isRestoring
                        ? null
                        : () {
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
                        color: _viewModel.isRestoring ? sc.muted : sc.accent,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
          body: Stack(
            children: [
              if (_viewModel.isLoading && !_viewModel.isRestoring)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFff2a7b), strokeWidth: 2),
                )
              else
                IgnorePointer(
                  ignoring: _viewModel.isRestoring,
                  child: _buildBody(sc, isDark),
                ),
              if (_viewModel.isRestoring)
                _buildRestoringProgressCard(sc, isDark),
            ],
          ),
          bottomNavigationBar: _viewModel.isSelectionMode
              ? _buildSelectionBottomBar(sc, isDark)
              : null,
        );
      },
    );
  }

  Widget _buildBody(SnapgroveColors sc, bool isDark) {
    if (_viewModel.allFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: sc.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(SnapSymbols.delete_outline, size: 38, color: sc.muted),
                ),
              ),
              const SizedBox(height: 18),
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
                'Items deleted from screenshots are moved here\nand automatically cleared after 30 days.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12.5,
                  color: sc.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 30 Days Retention Notice Banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sc.surfaceMuted.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sc.border),
          ),
          child: Row(
            children: [
              Icon(SnapSymbols.info_outline, size: 16, color: sc.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Items are permanently deleted after 30 days.',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11.5,
                    color: sc.muted,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Folder Filter Chips
        if (_viewModel.filterChips.length > 2)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _viewModel.filterChips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chip = _viewModel.filterChips[index];
                final isSelected = _viewModel.activeFilter == chip.folderName;

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _viewModel.setFilter(chip.folderName),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F3F3)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark ? const Color(0x33FFFFFF) : const Color(0x22000000)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chip.label,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.25))
                                : sc.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${chip.count}',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : sc.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 6),

        // Unified Thumbnail Grid
        Expanded(
          child: _buildFilesGrid(sc, isDark),
        ),
      ],
    );
  }

  Widget _buildFilesGrid(SnapgroveColors sc, bool isDark) {
    final files = _viewModel.files;

    if (files.isEmpty) {
      return Center(
        child: Text(
          'No items in this category',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 14,
            color: sc.muted,
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 5 : (width > 600 ? 4 : 3);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
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

  Widget _buildRestoringProgressCard(SnapgroveColors sc, bool isDark) {
    final current = _viewModel.restoreCurrent;
    final total = _viewModel.restoreTotal;
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : null;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 16 + bottomInset,
      left: 16,
      right: 16,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sc.accent.withValues(alpha: 0.5),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        total > 0
                            ? 'Restoring $current of $total files...'
                            : 'Restoring files...',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        '${((progress ?? 0) * 100).toInt()}%',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sc.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
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

  Widget _buildSelectionBottomBar(SnapgroveColors sc, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(top: BorderSide(color: sc.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Restore Button (Solid / Primary)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: (_viewModel.selectedCount > 0 && !_viewModel.isRestoring) ? _restoreSelected : null,
              icon: _viewModel.isRestoring
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.black : Colors.white),
                      ),
                    )
                  : const Icon(SnapSymbols.restore_rounded, size: 19),
              label: Text(
                _viewModel.isRestoring
                    ? 'Restoring...'
                    : 'Restore (${_viewModel.selectedCount})',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Delete Permanently Button (Destructive Outlined)
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: (_viewModel.selectedCount > 0 && !_viewModel.isRestoring) ? _confirmDeleteSelected : null,
              icon: const Icon(SnapSymbols.delete_forever, size: 19, color: Color(0xFFEF4444)),
              label: Text(
                'Delete (${_viewModel.selectedCount})',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
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
          // Image / Thumbnail
          Container(
            color: sc.surfaceMuted,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: sc.accent))
                : (_decryptedBytes != null
                    ? Image.memory(
                        _decryptedBytes!,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(SnapSymbols.broken_image_outlined, color: sc.muted, size: 28),
                        ),
                      )
                    : Center(
                        child: Icon(SnapSymbols.broken_image_outlined, color: sc.muted, size: 28),
                      )),
          ),

          // Bottom Gradient Overlay with Days & Folder Badge
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Days Remaining Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: days <= 5
                          ? const Color(0xFFEF4444).withValues(alpha: 0.9)
                          : Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${days}d',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Origin Folder Pill
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.file.folderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selection Overlay Indicator
          if (widget.isSelectionMode)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.isSelected ? const Color(0xFFff2a7b) : Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(SnapSymbols.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),

          // Selection Border Highlight
          if (widget.isSelected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFff2a7b),
                  width: 3,
                ),
              ),
            ),

          // Tap gesture
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color border;

    if (isDestructive) {
      bg = isPrimary ? const Color(0xFFEF4444) : Colors.transparent;
      fg = isPrimary ? Colors.white : const Color(0xFFEF4444);
      border = isPrimary ? Colors.transparent : const Color(0xFFEF4444).withValues(alpha: 0.4);
    } else if (isPrimary) {
      bg = isDark ? Colors.white : Colors.black;
      fg = isDark ? Colors.black : Colors.white;
      border = Colors.transparent;
    } else {
      bg = Colors.transparent;
      fg = isDark ? Colors.white70 : Colors.black87;
      border = sc.border;
    }

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
