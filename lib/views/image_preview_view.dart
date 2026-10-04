import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import '../core/locator.dart';
import '../services/file_service.dart';
import '../services/notification_service.dart';
import '../services/share/share_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/gallery_view_model.dart';

class ImagePreviewView extends StatefulWidget {
  final List<String> files;
  final int initialIndex;
  final String? directoryPath;
  final List<String>? subfolders;
  final Future<bool> Function(String name)? onFolderCreated;
  final Future<bool> Function(String filePath, String folderName)? onFileMoved;
  final Future<bool> Function(String filePath)? onFileDeleted;
  final Future<bool> Function(String filePath)? onFileMoveToBin;

  const ImagePreviewView({
    super.key,
    required this.files,
    required this.initialIndex,
    this.directoryPath,
    this.subfolders,
    this.onFolderCreated,
    this.onFileMoved,
    this.onFileDeleted,
    this.onFileMoveToBin,
  });

  @override
  State<ImagePreviewView> createState() => _ImagePreviewViewState();
}

class _ImagePreviewViewState extends State<ImagePreviewView> {
  late PageController _pageController;
  late List<String> _files;
  late List<String> _subfolders;
  int _currentIndex = 0;
  bool _isDesktopOrWeb = false;
  bool _isFullScreen = false;

  // Zoom and Drag state
  late TransformationController _transformController;
  double _currentZoom = 1.0;
  Timer? _zoomCapsuleTimer;
  bool _showZoomCapsule = false;
  bool _isDragging = false;

  // Horizontal scroll controller for tags
  final ScrollController _tagsScrollController = ScrollController();
  bool _canScrollTagsLeft = false;
  bool _canScrollTagsRight = false;

  @override
  void initState() {
    super.initState();
    _files = List<String>.from(widget.files);
    _subfolders = List<String>.from(widget.subfolders ?? []);
    _currentIndex = widget.initialIndex.clamp(0, _files.isNotEmpty ? _files.length - 1 : 0);
    _pageController = PageController(initialPage: _currentIndex);
    _isDesktopOrWeb = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    _transformController = TransformationController();
    _transformController.addListener(_onZoomChanged);
    _tagsScrollController.addListener(_updateTagsScrollIndicators);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTagsScrollIndicators();
      _preloadAdjacent(_currentIndex);
    });

    if (_subfolders.isEmpty && widget.directoryPath != null && widget.directoryPath!.isNotEmpty) {
      _loadSubfolders();
    }
  }

  void _preloadAdjacent(int index) {
    for (final offset in [-1, 1]) {
      final target = index + offset;
      if (target >= 0 && target < _files.length) {
        final path = _files[target];
        if ((kIsWeb || path.startsWith('content://')) && !_PreviewImageTileState.isCached(path)) {
          locator<FileService>().readFile(path).then((bytes) {
            if (bytes != null) {
              _PreviewImageTileState.addToCache(path, bytes);
            }
          }).catchError((_) {});
        }
      }
    }
  }

  void _updateTagsScrollIndicators() {
    if (!_tagsScrollController.hasClients) return;
    final maxScroll = _tagsScrollController.position.maxScrollExtent;
    final currentOffset = _tagsScrollController.offset;
    final canLeft = currentOffset > 4.0;
    final canRight = currentOffset < (maxScroll - 4.0) && maxScroll > 0;

    if (canLeft != _canScrollTagsLeft || canRight != _canScrollTagsRight) {
      if (mounted) {
        setState(() {
          _canScrollTagsLeft = canLeft;
          _canScrollTagsRight = canRight;
        });
      }
    }
  }

  void _scrollTags(double delta) {
    if (!_tagsScrollController.hasClients) return;
    final target = (_tagsScrollController.offset + delta).clamp(
      0.0,
      _tagsScrollController.position.maxScrollExtent,
    );
    _tagsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadSubfolders() async {
    try {
      final folders = await locator<FileService>().listSubfolders(widget.directoryPath!);
      if (mounted) {
        setState(() {
          _subfolders = folders;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateTagsScrollIndicators();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    _tagsScrollController.removeListener(_updateTagsScrollIndicators);
    _tagsScrollController.dispose();
    _zoomCapsuleTimer?.cancel();
    super.dispose();
  }

  void _onZoomChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentZoom).abs() < 0.01) return;

    if (mounted) {
      setState(() {
        _currentZoom = scale;
        _showZoomCapsule = true;
      });
      _zoomCapsuleTimer?.cancel();

      if (_currentZoom <= 1.01) {
        _zoomCapsuleTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showZoomCapsule = false;
            });
          }
        });
      }
    }
  }

  void _setZoom(double targetZoom, [Offset? focalPoint]) {
    if (targetZoom <= 1.01) {
      _transformController.value = Matrix4.identity();
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Size size = box?.hasSize == true ? box!.size : (MediaQuery.maybeOf(context)?.size ?? Size.zero);
    final double cx = (focalPoint?.dx ?? (size.width / 2.0)).clamp(0.0, size.width);
    final double cy = (focalPoint?.dy ?? (size.height / 2.0)).clamp(0.0, size.height);

    final double tx = (size.width / 2.0 - cx) * (targetZoom - 1.0);
    final double ty = (size.height / 2.0 - cy) * (targetZoom - 1.0);

    final Matrix4 matrix = Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(targetZoom, targetZoom, 1.0, 1.0);
    _transformController.value = matrix;
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_currentZoom > 1.05) {
      _setZoom(1.0);
    } else {
      _setZoom(2.0, details.localPosition);
    }
  }

  void _goNext() {
    if (_currentIndex < _files.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  Future<void> _shareCurrentImage() async {
    if (_files.isEmpty) return;
    final currentPath = _files[_currentIndex];
    final fileName = p.basename(currentPath).replaceAll('%2F', '/').split('/').last;

    Uint8List? bytes;
    try {
      if (kIsWeb || currentPath.startsWith('content://')) {
        bytes = await locator<FileService>().readFile(currentPath);
      }
    } catch (_) {}

    final shared = await locator<ShareService>().shareImageFile(
      filePath: currentPath,
      fileName: fileName,
      bytes: bytes,
    );

    if (!shared) {
      await Clipboard.setData(ClipboardData(text: currentPath));
      locator<NotificationService>().showSnackBar('Image path copied to clipboard');
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final sc = context.snapgroveColors;
    final controller = TextEditingController();

    final folderName = await showGeneralDialog<String>(
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
              width: MediaQuery.of(ctx).size.width * 0.9 > 360 ? 360 : MediaQuery.of(ctx).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: sc.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
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
                  const Text(
                    'Create Folder',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Folder name',
                      hintStyle: TextStyle(color: sc.muted.withValues(alpha: 0.6), fontSize: 13),
                      filled: true,
                      fillColor: sc.surfaceMuted,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: sc.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFf89838), width: 1.5),
                      ),
                    ),
                    onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogActionButton(
                        label: 'Cancel',
                        isPrimary: false,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                      const SizedBox(width: 8),
                      _DialogActionButton(
                        label: 'Create',
                        isPrimary: true,
                        onTap: () => Navigator.of(ctx).pop(controller.text.trim()),
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

    if (folderName != null && folderName.isNotEmpty) {
      bool success = false;
      if (widget.onFolderCreated != null) {
        success = await widget.onFolderCreated!(folderName);
      } else if (widget.directoryPath != null) {
        success = await locator<FileService>().createSubfolder(widget.directoryPath!, folderName);
      }

      if (success) {
        if (!_subfolders.contains(folderName)) {
          setState(() {
            _subfolders.add(folderName);
            _subfolders.sort();
          });
        }
        locator<NotificationService>().showSnackBar('Folder "$folderName" created');
      } else {
        locator<NotificationService>().showSnackBar('Failed to create folder', isError: true);
      }
    }
  }

  String? _getSubfolderTag(String filePath) {
    return GalleryViewModel.extractSubfolderTag(widget.directoryPath ?? '', filePath);
  }

  Future<void> _moveImageToFolder(String folderName) async {
    if (_files.isEmpty) return;
    final currentPath = _files[_currentIndex];
    final fileName = p.basename(currentPath).replaceAll('%2F', '/').split('/').last;

    final String? currentTag = _getSubfolderTag(currentPath);
    final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
    final bool isAlreadyInDest = isMovingToRoot
        ? (currentTag == null)
        : (currentTag != null && currentTag.toLowerCase() == folderName.toLowerCase());

    if (isAlreadyInDest) {
      locator<NotificationService>().showSnackBar(
        isMovingToRoot ? 'This image is already in root' : 'This image is already in $folderName',
      );
      return;
    }

    // Optimistic removal from preview
    final currentIndex = _currentIndex;
    setState(() {
      _files.removeAt(currentIndex);
      if (_files.isEmpty) {
        Navigator.of(context).pop();
      } else if (_currentIndex >= _files.length) {
        _currentIndex = _files.length - 1;
      }
    });

    locator<NotificationService>().showSnackBar(
      'Moved "$fileName" to $folderName',
      actionLabel: 'Undo',
      onAction: () async {
        if (widget.directoryPath != null) {
          final undoSuccess = await locator<FileService>().undoMoveFiles(widget.directoryPath!, folderName, [currentPath]);
          if (undoSuccess) {
            if (mounted) {
              setState(() {
                _files.insert(currentIndex.clamp(0, _files.length), currentPath);
              });
            }
            locator<NotificationService>().showSnackBar('Restored "$fileName"');
          }
        }
      },
      duration: const Duration(seconds: 6),
    );

    // Perform file move in background
    if (widget.onFileMoved != null) {
      widget.onFileMoved!(currentPath, folderName);
    } else if (widget.directoryPath != null) {
      locator<FileService>().moveFilesToFolder(widget.directoryPath!, folderName, [currentPath]);
    }
  }

  Future<void> _confirmDelete() async {
    if (_files.isEmpty) return;
    final currentPath = _files[_currentIndex];
    final fileName = p.basename(currentPath).replaceAll('%2F', '/').split('/').last;
    final sc = context.snapgroveColors;

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
        ? 'Are you sure you want to permanently delete "$fileName"?'
        : '"$fileName" is being moved to the $destinationName.';

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
                      const Text(
                        'Delete image?',
                        style: TextStyle(
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
      final currentIndex = _currentIndex;
      setState(() {
        _files.removeAt(currentIndex);
        if (_files.isEmpty) {
          Navigator.of(context).pop();
        } else if (_currentIndex >= _files.length) {
          _currentIndex = _files.length - 1;
        }
      });

      bool success;
      if (widget.onFileMoveToBin != null) {
        success = await widget.onFileMoveToBin!(currentPath);
      } else {
        success = await locator<FileService>().moveToBin(widget.directoryPath ?? '', [currentPath]);
      }
      if (success) {
        locator<NotificationService>().showSnackBar('Moved to $destinationName');
      } else {
        locator<NotificationService>().showSnackBar('Failed to move image to $destinationName', isError: true);
      }
    } else if (choice == 'permanent' && mounted) {
      final currentIndex = _currentIndex;
      setState(() {
        _files.removeAt(currentIndex);
        if (_files.isEmpty) {
          Navigator.of(context).pop();
        } else if (_currentIndex >= _files.length) {
          _currentIndex = _files.length - 1;
        }
      });

      bool success;
      if (widget.onFileDeleted != null) {
        success = await widget.onFileDeleted!(currentPath);
      } else {
        success = await locator<FileService>().deleteFilesPermanently([currentPath]);
      }
      if (success) {
        locator<NotificationService>().showSnackBar('Permanently deleted');
      } else {
        locator<NotificationService>().showSnackBar('Failed to delete image', isError: true);
      }
    }
  }

  Future<void> _showInfoDialog() async {
    if (_files.isEmpty) return;
    String currentPath = _files[_currentIndex];
    String currentFileName = p.basename(currentPath).replaceAll('%2F', '/').split('/').last;
    String extension = p.extension(currentPath).toUpperCase().replaceAll('.', '');
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int? fileSize;
    DateTime? modifiedDate;
    int? imgWidth;
    int? imgHeight;

    try {
      if (!kIsWeb && !currentPath.startsWith('content://')) {
        final f = File(currentPath);
        if (await f.exists()) {
          final stat = await f.stat();
          fileSize = stat.size;
          modifiedDate = stat.modified;
        }
      }

      final bytes = await locator<FileService>().readFile(currentPath);
      if (bytes != null) {
        fileSize ??= bytes.length;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        imgWidth = frame.image.width;
        imgHeight = frame.image.height;
        frame.image.dispose();
      }
    } catch (_) {}

    String formatBytes(int? bytes) {
      if (bytes == null) return 'Unknown';
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    String formatDate(DateTime? dt) {
      if (dt == null) return 'Unknown';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> handleRename() async {
              final renameController = TextEditingController(text: currentFileName);
              final newName = await showGeneralDialog<String>(
                context: ctx,
                barrierDismissible: true,
                barrierLabel: 'Dismiss',
                barrierColor: Colors.black.withValues(alpha: 0.6),
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (dCtx, a1, a2) {
                  return Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: MediaQuery.of(dCtx).size.width * 0.88 > 360 ? 360 : MediaQuery.of(dCtx).size.width * 0.88,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: sc.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
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
                            const Text(
                              'Rename Image',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: renameController,
                              autofocus: true,
                              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'New file name',
                                hintStyle: TextStyle(color: sc.muted.withValues(alpha: 0.6), fontSize: 13),
                                filled: true,
                                fillColor: sc.surfaceMuted,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: sc.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFf89838), width: 1.5),
                                ),
                              ),
                              onSubmitted: (val) => Navigator.of(dCtx).pop(val.trim()),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _DialogActionButton(
                                  label: 'Cancel',
                                  isPrimary: false,
                                  onTap: () => Navigator.of(dCtx).pop(),
                                ),
                                const SizedBox(width: 8),
                                _DialogActionButton(
                                  label: 'Rename',
                                  isPrimary: true,
                                  onTap: () => Navigator.of(dCtx).pop(renameController.text.trim()),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                transitionBuilder: (dCtx, a1, a2, child) {
                  final curve = Curves.easeOutBack.transform(a1.value);
                  return Transform.scale(
                    scale: 0.9 + (0.1 * curve),
                    child: Opacity(opacity: a1.value, child: child),
                  );
                },
              );

              if (newName != null && newName.isNotEmpty && newName != currentFileName) {
                final renamedPath = await locator<FileService>().renameFile(currentPath, newName);
                if (renamedPath != null) {
                  if (mounted) {
                    setState(() {
                      _files[_currentIndex] = renamedPath;
                    });
                  }
                  setDialogState(() {
                    currentPath = renamedPath;
                    currentFileName = newName;
                    extension = p.extension(renamedPath).toUpperCase().replaceAll('.', '');
                  });
                  locator<NotificationService>().showSnackBar('Renamed to "$newName"');
                } else {
                  locator<NotificationService>().showSnackBar('Failed to rename file', isError: true);
                }
              }
            }

            Future<void> handleEditDateTime() async {
              final initial = modifiedDate ?? DateTime.now();
              final pickedDate = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: DateTime(1970),
                lastDate: DateTime(2100),
                builder: (pickerContext, child) {
                  return Theme(
                    data: Theme.of(pickerContext).copyWith(
                      colorScheme: isDark
                          ? const ColorScheme.dark(
                              primary: Color(0xFFf89838),
                              surface: Color(0xFF242424),
                            )
                          : const ColorScheme.light(
                              primary: Color(0xFFf89838),
                              surface: Colors.white,
                            ),
                    ),
                    child: child!,
                  );
                },
              );

              if (pickedDate == null || !mounted || !ctx.mounted) return;

              final pickedTime = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay.fromDateTime(initial),
                builder: (pickerContext, child) {
                  return Theme(
                    data: Theme.of(pickerContext).copyWith(
                      colorScheme: isDark
                          ? const ColorScheme.dark(
                              primary: Color(0xFFf89838),
                              surface: Color(0xFF242424),
                            )
                          : const ColorScheme.light(
                              primary: Color(0xFFf89838),
                              surface: Colors.white,
                            ),
                    ),
                    child: child!,
                  );
                },
              );

              if (pickedTime == null || !mounted) return;

              final newDateTime = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );

              final success = await locator<FileService>().updateModifiedDate(currentPath, newDateTime);
              if (success) {
                setDialogState(() {
                  modifiedDate = newDateTime;
                });
                locator<NotificationService>().showSnackBar('Modified date & time updated');
              } else {
                locator<NotificationService>().showSnackBar('Failed to update date & time', isError: true);
              }
            }

            Future<void> handleRemoveExif() async {
              final success = await locator<FileService>().removeExifData(currentPath);
              if (success) {
                try {
                  if (!kIsWeb && !currentPath.startsWith('content://')) {
                    final f = File(currentPath);
                    if (await f.exists()) {
                      final stat = await f.stat();
                      fileSize = stat.size;
                      modifiedDate = stat.modified;
                    }
                  } else {
                    final bytes = await locator<FileService>().readFile(currentPath);
                    if (bytes != null) fileSize = bytes.length;
                  }
                } catch (_) {}

                setDialogState(() {});
                locator<NotificationService>().showSnackBar('EXIF metadata removed');
              } else {
                locator<NotificationService>().showSnackBar('Failed to remove EXIF data', isError: true);
              }
            }

            return Center(
              child: Material(
                color: Colors.transparent,
                child: SelectionArea(
                  child: Container(
                    width: MediaQuery.of(ctx).size.width * 0.92 > 480 ? 480 : MediaQuery.of(ctx).size.width * 0.92,
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: isDark ? Colors.white : Colors.black),
                                const SizedBox(width: 8),
                                const Text(
                                  'Image Details',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            _DialogCloseButton(
                              onTap: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(ctx).size.height * 0.62,
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: sc.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: sc.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _DetailRow(
                                    label: 'File Name',
                                    value: currentFileName,
                                    trailing: _EditIconButton(
                                      tooltip: 'Rename',
                                      onTap: handleRename,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _DetailRow(
                                    label: 'Resolution',
                                    value: imgWidth != null && imgHeight != null
                                        ? '$imgWidth × $imgHeight (${(imgWidth * imgHeight / 1000000).toStringAsFixed(2)} MP)'
                                        : 'Loading...',
                                  ),
                                  const SizedBox(height: 8),
                                  _DetailRow(label: 'File Size', value: formatBytes(fileSize)),
                                  const SizedBox(height: 8),
                                  _DetailRow(label: 'Format', value: extension.isEmpty ? 'Image' : extension),
                                  const SizedBox(height: 8),
                                  _DetailRow(
                                    label: 'Modified',
                                    value: formatDate(modifiedDate),
                                    trailing: _EditIconButton(
                                      tooltip: 'Edit Date & Time',
                                      onTap: handleEditDateTime,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _DetailRow(label: 'Location', value: currentPath, isPath: true),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _DialogActionButton(
                              label: 'Remove EXIF',
                              isPrimary: false,
                              onTap: handleRemoveExif,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _DialogActionButton(
                                  label: 'Copy Path',
                                  isPrimary: false,
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: currentPath));
                                    Navigator.of(ctx).pop();
                                    locator<NotificationService>().showSnackBar('Path copied to clipboard');
                                  },
                                ),
                                const SizedBox(width: 8),
                                _DialogActionButton(
                                  label: 'Close',
                                  isPrimary: true,
                                  onTap: () => Navigator.of(ctx).pop(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
  }

  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No images to display', style: TextStyle(color: Colors.white))),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;
    final currentPath = _files[_currentIndex];
    final fileName = p.basename(currentPath).replaceAll('%2F', '/').split('/').last;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (_isFullScreen) {
                _toggleFullScreen();
              } else {
                Navigator.of(context).pop();
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _goNext();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _goPrev();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            // Main Image Viewer
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (_isFullScreen) _toggleFullScreen();
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _files.length,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentIndex = idx;
                      _transformController.value = Matrix4.identity();
                    });
                    _preloadAdjacent(idx);
                  },
                  itemBuilder: (context, index) {
                    final path = _files[index];
                    return Listener(
                      onPointerSignal: (pointerSignal) {
                        if (pointerSignal is PointerScrollEvent) {
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            final delta = pointerSignal.scrollDelta.dy;
                            double newZoom = _currentZoom - (delta / 500);
                            newZoom = newZoom.clamp(1.0, 5.0);
                            _setZoom(newZoom);
                          }
                        }
                      },
                      child: GestureDetector(
                        onDoubleTapDown: _handleDoubleTap,
                        child: MouseRegion(
                          cursor: _isDesktopOrWeb
                              ? (_isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
                              : MouseCursor.defer,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 1.0,
                            maxScale: 5.0,
                            onInteractionStart: (_) {
                              if (mounted) setState(() => _isDragging = true);
                            },
                            onInteractionEnd: (_) {
                              if (mounted) setState(() => _isDragging = false);
                            },
                            child: Hero(
                              tag: index == _currentIndex ? path : 'preview_$path',
                              child: Center(
                                child: _buildImage(context, path),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Exit Fullscreen Button
            if (_isFullScreen)
              Positioned(
                top: 16,
                right: 16,
                child: SafeArea(
                  child: _ExitFullScreenButton(onTap: _toggleFullScreen),
                ),
              ),

            // Left / Right Navigation Arrows (Desktop / Web)
            if (!_isFullScreen && _isDesktopOrWeb && _currentIndex > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _NavArrowButton(
                    icon: Icons.chevron_left,
                    tooltip: 'Previous Image',
                    onTap: _goPrev,
                  ),
                ),
              ),
            if (!_isFullScreen && _isDesktopOrWeb && _currentIndex < _files.length - 1)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _NavArrowButton(
                    icon: Icons.chevron_right,
                    tooltip: 'Next Image',
                    onTap: _goNext,
                  ),
                ),
              ),

            // Zoom UI (Capsule + Slider)
            if (!_isFullScreen)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isWide ? 32.0 : 80.0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showZoomCapsule ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_showZoomCapsule,
                      child: Container(
                        height: 48,
                        width: _isDesktopOrWeb ? 400 : null,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(_currentZoom * 100).toInt()}%',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            if (_isDesktopOrWeb) ...[
                              const SizedBox(width: 16),
                              const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                              Expanded(
                                child: Slider(
                                  value: _currentZoom,
                                  min: 1.0,
                                  max: 5.0,
                                  activeColor: const Color(0xFFf89838),
                                  inactiveColor: Colors.white30,
                                  onChanged: (val) => _setZoom(val),
                                ),
                              ),
                              const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Top Header & Tags Pane Overlay
            if (!_isFullScreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              // Back button
                              _RoundBackButton(
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 8),

                              // File name badge at center
                              Expanded(
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF242424).withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0x33FFFFFF)),
                                    ),
                                    child: Text(
                                      fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Lora',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Actions on Desktop / Web
                              if (isWide) ...[
                                _PreviewActionButton(
                                  icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                  tooltip: 'Fullscreen',
                                  onTap: _toggleFullScreen,
                                ),
                                const SizedBox(width: 6),
                                _PreviewActionButton(
                                  icon: Icons.share_outlined,
                                  tooltip: 'Share',
                                  onTap: _shareCurrentImage,
                                ),
                                const SizedBox(width: 6),
                                _PreviewActionButton(
                                  icon: Icons.info_outline,
                                  tooltip: 'Info',
                                  onTap: _showInfoDialog,
                                ),
                                const SizedBox(width: 6),
                                _PreviewActionButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Delete',
                                  isDestructive: true,
                                  onTap: _confirmDelete,
                                ),
                              ] else ...[
                                // Create Folder on mobile header
                                _CreateFolderPillButton(
                                  onTap: _showCreateFolderDialog,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Categories / Tags Pane
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                          child: Row(
                            children: [
                              if (isWide) ...[
                                _CreateFolderPillButton(
                                  onTap: _showCreateFolderDialog,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: SizedBox(
                                  height: 32,
                                  child: Row(
                                    children: [
                                      if (_canScrollTagsLeft) ...[
                                        _ScrollIndicatorArrow(
                                          direction: AxisDirection.left,
                                          isVisible: _canScrollTagsLeft,
                                          onTap: () => _scrollTags(-140),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: ListView.separated(
                                          controller: _tagsScrollController,
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: _subfolders.length + 1,
                                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                                          itemBuilder: (context, index) {
                                            final currentPath = _files.isNotEmpty && _currentIndex < _files.length
                                                ? _files[_currentIndex]
                                                : '';
                                            final currentTag = _getSubfolderTag(currentPath);

                                            if (index == 0) {
                                              final isEnabled = currentTag != null;
                                              return _CategoryPillChip(
                                                label: 'ROOT',
                                                isRoot: true,
                                                isEnabled: isEnabled,
                                                tooltip: isEnabled ? null : 'This image is already in root',
                                                onTap: isEnabled ? () => _moveImageToFolder('ROOT') : null,
                                              );
                                            }
                                            final tag = _subfolders[index - 1];
                                            final isEnabled = currentTag == null || currentTag.toLowerCase() != tag.toLowerCase();
                                            return _CategoryPillChip(
                                              label: tag,
                                              isEnabled: isEnabled,
                                              tooltip: isEnabled ? null : 'This image is already in $tag',
                                              onTap: isEnabled ? () => _moveImageToFolder(tag) : null,
                                            );
                                          },
                                        ),
                                      ),
                                      if (_canScrollTagsRight) ...[
                                        const SizedBox(width: 4),
                                        _ScrollIndicatorArrow(
                                          direction: AxisDirection.right,
                                          isVisible: _canScrollTagsRight,
                                          onTap: () => _scrollTags(140),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom Action Bar (Mobile and Small Screen)
            if (!_isFullScreen && !isWide)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818).withValues(alpha: 0.95),
                    border: const Border(top: BorderSide(color: Color(0x22FFFFFF))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _BottomBarAction(
                            icon: Icons.delete_outline,
                            label: 'Bin',
                            isDestructive: true,
                            onTap: _confirmDelete,
                          ),
                          _BottomBarAction(
                            icon: Icons.info_outline,
                            label: 'Info',
                            onTap: _showInfoDialog,
                          ),
                          _BottomBarAction(
                            icon: Icons.share_outlined,
                            label: 'Share',
                            onTap: _shareCurrentImage,
                          ),
                          _BottomBarAction(
                            icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                            label: 'Fullscreen',
                            onTap: _toggleFullScreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String path) {
    return _PreviewImageTile(path: path);
  }
}

class _PreviewImageTile extends StatefulWidget {
  final String path;
  const _PreviewImageTile({required this.path});

  @override
  State<_PreviewImageTile> createState() => _PreviewImageTileState();
}

class _PreviewImageTileState extends State<_PreviewImageTile> {
  static final Map<String, Uint8List> _previewCache = {};
  static final List<String> _cacheKeys = [];
  static const int _maxCacheSize = 25;

  Uint8List? _bytes;
  bool _hasError = false;

  static bool isCached(String path) => _previewCache.containsKey(path);

  static void addToCache(String key, Uint8List bytes) {
    if (_cacheKeys.length >= _maxCacheSize) {
      final oldest = _cacheKeys.removeAt(0);
      _previewCache.remove(oldest);
    }
    _previewCache[key] = bytes;
    _cacheKeys.remove(key);
    _cacheKeys.add(key);
  }

  static void _touchCache(String key) {
    _cacheKeys.remove(key);
    _cacheKeys.add(key);
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_PreviewImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loadImage();
    }
  }

  void _loadImage() {
    if (!kIsWeb && !widget.path.startsWith('content://')) {
      return;
    }

    if (_previewCache.containsKey(widget.path)) {
      _touchCache(widget.path);
      setState(() {
        _bytes = _previewCache[widget.path];
        _hasError = false;
      });
      return;
    }

    setState(() {
      _hasError = false;
    });

    final targetPath = widget.path;
    locator<FileService>().readFile(targetPath).then((bytes) {
      if (!mounted || widget.path != targetPath) return;
      if (bytes != null) {
        addToCache(targetPath, bytes);
        setState(() {
          _bytes = bytes;
          _hasError = false;
        });
      } else {
        setState(() {
          _hasError = true;
        });
      }
    }).catchError((_) {
      if (!mounted || widget.path != targetPath) return;
      setState(() {
        _hasError = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && !widget.path.startsWith('content://')) {
      return Image.file(
        File(widget.path),
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    if (_hasError) {
      return const Icon(Icons.broken_image, size: 100, color: Colors.white);
    }

    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
}

class _RoundBackButton extends StatefulWidget {
  final VoidCallback onTap;

  const _RoundBackButton({required this.onTap});

  @override
  State<_RoundBackButton> createState() => _RoundBackButtonState();
}

class _RoundBackButtonState extends State<_RoundBackButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _isHovered
              ? Colors.white.withValues(alpha: 0.22)
              : const Color(0xFF242424).withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            splashColor: Colors.white.withValues(alpha: 0.25),
            highlightColor: Colors.white.withValues(alpha: 0.12),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/Back-Btn.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDestructive;

  const _PreviewActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_PreviewActionButton> createState() => _PreviewActionButtonState();
}

class _PreviewActionButtonState extends State<_PreviewActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.isDestructive && _isHovered
        ? const Color(0xFFEF4444)
        : Colors.white;

    final Color bgColor = _isHovered
        ? (widget.isDestructive
            ? const Color(0xFFEF4444).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.18))
        : const Color(0xFF242424).withValues(alpha: 0.9);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              hoverColor: Colors.transparent,
              splashColor: widget.isDestructive
                  ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.25),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 19,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavArrowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _NavArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_NavArrowButton> createState() => _NavArrowButtonState();
}

class _NavArrowButtonState extends State<_NavArrowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF383838).withValues(alpha: 0.95)
                : Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isHovered ? const Color(0x66FFFFFF) : const Color(0x22FFFFFF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              hoverColor: Colors.transparent,
              splashColor: Colors.white.withValues(alpha: 0.25),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitFullScreenButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ExitFullScreenButton({required this.onTap});

  @override
  State<_ExitFullScreenButton> createState() => _ExitFullScreenButtonState();
}

class _ExitFullScreenButtonState extends State<_ExitFullScreenButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Exit Fullscreen (Esc)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF383838).withValues(alpha: 0.95)
                : const Color(0xFF181818).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? const Color(0x88FFFFFF) : const Color(0x33FFFFFF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: Colors.white.withValues(alpha: 0.2),
              hoverColor: Colors.transparent,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_exit, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Exit',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
  }
}

class _ScrollIndicatorArrow extends StatefulWidget {
  final AxisDirection direction;
  final bool isVisible;
  final VoidCallback onTap;

  const _ScrollIndicatorArrow({
    required this.direction,
    required this.isVisible,
    required this.onTap,
  });

  @override
  State<_ScrollIndicatorArrow> createState() => _ScrollIndicatorArrowState();
}

class _ScrollIndicatorArrowState extends State<_ScrollIndicatorArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final isLeft = widget.direction == AxisDirection.left;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 32,
        decoration: BoxDecoration(
          color: _isHovered
              ? const Color(0xFF3E3E3E).withValues(alpha: 0.95)
              : const Color(0xFF222222).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? const Color(0x66FFFFFF) : const Color(0x28FFFFFF),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            splashColor: Colors.white.withValues(alpha: 0.2),
            child: Center(
              child: Icon(
                isLeft ? Icons.chevron_left : Icons.chevron_right,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateFolderPillButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CreateFolderPillButton({required this.onTap});

  @override
  State<_CreateFolderPillButton> createState() => _CreateFolderPillButtonState();
}

class _CreateFolderPillButtonState extends State<_CreateFolderPillButton> {
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
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFFf89838).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: _isHovered ? hoverBg : defaultBg,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: Colors.black.withValues(alpha: 0.25),
            highlightColor: Colors.black.withValues(alpha: 0.12),
            hoverColor: Colors.transparent,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.create_new_folder, size: 14, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    'Create Folder',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
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

class _CategoryPillChip extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isRoot;
  final bool isEnabled;
  final String? tooltip;

  const _CategoryPillChip({
    required this.label,
    required this.onTap,
    this.isRoot = false,
    this.isEnabled = true,
    this.tooltip,
  });

  @override
  State<_CategoryPillChip> createState() => _CategoryPillChipState();
}

class _CategoryPillChipState extends State<_CategoryPillChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.isEnabled && widget.onTap != null;
    final Color bgColor;
    final Color borderColor;
    final Color contentColor;

    if (widget.isRoot) {
      if (!isEnabled) {
        bgColor = const Color(0xFFf89838).withValues(alpha: 0.06);
        borderColor = const Color(0xFFf89838).withValues(alpha: 0.2);
        contentColor = const Color(0xFFf89838).withValues(alpha: 0.35);
      } else {
        bgColor = _isHovered
            ? const Color(0xFFf89838).withValues(alpha: 0.35)
            : const Color(0xFFf89838).withValues(alpha: 0.22);
        borderColor = const Color(0xFFf89838);
        contentColor = const Color(0xFFf89838);
      }
    } else {
      if (!isEnabled) {
        bgColor = const Color(0xFF1E1E1E).withValues(alpha: 0.4);
        borderColor = const Color(0x18FFFFFF);
        contentColor = Colors.white.withValues(alpha: 0.3);
      } else {
        bgColor = _isHovered ? const Color(0xFF383838) : const Color(0xFF242424);
        borderColor = _isHovered ? const Color(0x66FFFFFF) : const Color(0x33FFFFFF);
        contentColor = Colors.white;
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isEnabled ? widget.onTap : null,
            splashColor: const Color(0xFFf89838).withValues(alpha: 0.35),
            highlightColor: const Color(0xFFf89838).withValues(alpha: 0.15),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isRoot ? Icons.home_outlined : Icons.folder_outlined,
                    size: 13,
                    color: widget.isRoot ? contentColor : (isEnabled ? Colors.white70 : contentColor),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
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

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      chip = Tooltip(
        message: widget.tooltip!,
        child: chip,
      );
    }

    return chip;
  }
}

class _BottomBarAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _BottomBarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_BottomBarAction> createState() => _BottomBarActionState();
}

class _BottomBarActionState extends State<_BottomBarAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.isDestructive
        ? const Color(0xFFEF4444)
        : (_isHovered ? const Color(0xFFf89838) : Colors.white);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: _isHovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          splashColor: widget.isDestructive
              ? const Color(0xFFEF4444).withValues(alpha: 0.3)
              : const Color(0xFFf89838).withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 22, color: iconColor),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPath;
  final Widget? trailing;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isPath = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sc.muted.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.35,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _EditIconButton extends StatefulWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _EditIconButton({
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_EditIconButton> createState() => _EditIconButtonState();
}

class _EditIconButtonState extends State<_EditIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: widget.onTap,
              splashColor: sc.rippleColor,
              child: Center(
                child: Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogCloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _DialogCloseButton({required this.onTap});

  @override
  State<_DialogCloseButton> createState() => _DialogCloseButtonState();
}

class _DialogCloseButtonState extends State<_DialogCloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            splashColor: Colors.white.withValues(alpha: 0.2),
            child: const Center(child: Icon(Icons.close, size: 18)),
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DialogActionButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_DialogActionButton> createState() => _DialogActionButtonState();
}

class _DialogActionButtonState extends State<_DialogActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color border;

    if (widget.isPrimary) {
      bg = _isHovered
          ? (isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333))
          : (isDark ? Colors.white : Colors.black);
      fg = isDark ? Colors.black : Colors.white;
      border = Colors.transparent;
    } else {
      bg = _isHovered ? sc.surfaceMuted : Colors.transparent;
      fg = isDark ? Colors.white70 : Colors.black87;
      border = sc.border;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            splashColor: sc.rippleColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

