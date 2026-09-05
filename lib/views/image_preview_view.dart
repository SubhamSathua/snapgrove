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
import '../theme/app_theme.dart';

class ImagePreviewView extends StatefulWidget {
  final List<String> files;
  final int initialIndex;
  final String? directoryPath;
  final List<String>? subfolders;
  final Future<bool> Function(String name)? onFolderCreated;
  final Future<bool> Function(String filePath, String folderName)? onFileMoved;
  final Future<bool> Function(String filePath)? onFileDeleted;

  const ImagePreviewView({
    super.key,
    required this.files,
    required this.initialIndex,
    this.directoryPath,
    this.subfolders,
    this.onFolderCreated,
    this.onFileMoved,
    this.onFileDeleted,
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

    if (_subfolders.isEmpty && widget.directoryPath != null && widget.directoryPath!.isNotEmpty) {
      _loadSubfolders();
    }
  }

  Future<void> _loadSubfolders() async {
    try {
      final folders = await locator<FileService>().listSubfolders(widget.directoryPath!);
      if (mounted) {
        setState(() {
          _subfolders = folders;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
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
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Size size = box?.hasSize == true ? box!.size : (MediaQuery.maybeOf(context)?.size ?? Size.zero);
    final double cx = focalPoint?.dx ?? (size.width / 2.0);
    final double cy = focalPoint?.dy ?? (size.height / 2.0);

    final Matrix4 matrix = Matrix4.identity()
      ..translateByDouble(cx * (1.0 - targetZoom), cy * (1.0 - targetZoom), 0.0, 1.0)
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

  void _shareCurrentImage() {
    if (_files.isEmpty) return;
    final currentPath = _files[_currentIndex];
    Clipboard.setData(ClipboardData(text: currentPath));
    locator<NotificationService>().showSnackBar('Image path copied to clipboard');
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

  Future<void> _moveImageToFolder(String folderName) async {
    if (_files.isEmpty) return;
    final currentPath = _files[_currentIndex];
    final fileName = p.basename(currentPath).replaceAll('%2F', '/').split('/').last;

    bool success = false;
    if (widget.onFileMoved != null) {
      success = await widget.onFileMoved!(currentPath, folderName);
    } else if (widget.directoryPath != null) {
      success = await locator<FileService>().moveFilesToFolder(widget.directoryPath!, folderName, [currentPath]);
    }

    if (success) {
      locator<NotificationService>().showSnackBar(
        'Moved "$fileName" to $folderName',
        actionLabel: 'Undo',
        onAction: () async {
          if (widget.directoryPath != null) {
            final undoSuccess = await locator<FileService>().undoMoveFiles(widget.directoryPath!, folderName, [currentPath]);
            if (undoSuccess) {
              if (mounted) {
                setState(() {
                  _files.insert(_currentIndex.clamp(0, _files.length), currentPath);
                });
              }
              locator<NotificationService>().showSnackBar('Restored "$fileName"');
            }
          }
        },
        duration: const Duration(seconds: 6),
      );

      setState(() {
        _files.removeAt(_currentIndex);
        if (_files.isEmpty) {
          Navigator.of(context).pop();
        } else if (_currentIndex >= _files.length) {
          _currentIndex = _files.length - 1;
        }
      });
    } else {
      locator<NotificationService>().showSnackBar('Failed to move image', isError: true);
    }
  }

  Future<void> _confirmDelete() async {
    if (_files.isEmpty) return;
    final currentPath = _files[_currentIndex];
    final fileName = p.basename(currentPath).replaceAll('%2F', '/').split('/').last;
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
                          child: Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Delete Image',
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
                    'Are you sure you want to permanently delete "$fileName"?',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 14,
                      color: sc.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogActionButton(
                        label: 'Cancel',
                        isPrimary: false,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 10),
                      _DialogActionButton(
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

    if (confirmed == true && mounted) {
      bool success = false;
      if (widget.onFileDeleted != null) {
        success = await widget.onFileDeleted!(currentPath);
      } else {
        success = await locator<FileService>().deleteFile(currentPath);
      }

      if (success) {
        locator<NotificationService>().showSnackBar('Image deleted');
        setState(() {
          _files.removeAt(_currentIndex);
          if (_files.isEmpty) {
            Navigator.of(context).pop();
          } else if (_currentIndex >= _files.length) {
            _currentIndex = _files.length - 1;
          }
        });
      } else {
        locator<NotificationService>().showSnackBar('Failed to delete image', isError: true);
      }
    }
  }

  Future<void> _showInfoDialog() async {
    if (_files.isEmpty) return;
    final currentPath = _files[_currentIndex];
    final fileName = p.basename(currentPath).replaceAll('%2F', '/').split('/').last;
    final extension = p.extension(currentPath).toUpperCase().replaceAll('.', '');
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
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.92 > 440 ? 440 : MediaQuery.of(ctx).size.width * 0.92,
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
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(ctx).pop(),
                            child: const Center(child: Icon(Icons.close, size: 18)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: sc.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sc.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: 'File Name', value: fileName),
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
                        if (modifiedDate != null) ...[
                          const SizedBox(height: 8),
                          _DetailRow(label: 'Modified', value: formatDate(modifiedDate)),
                        ],
                        const SizedBox(height: 8),
                        _DetailRow(label: 'Location', value: currentPath, isPath: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
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

            // Left / Right Navigation Arrows (Desktop / Web)
            if (!_isFullScreen && _isDesktopOrWeb && _currentIndex > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FloatingActionButton(
                    heroTag: 'prev_btn',
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    onPressed: _goPrev,
                    child: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                ),
              ),
            if (!_isFullScreen && _isDesktopOrWeb && _currentIndex < _files.length - 1)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FloatingActionButton(
                    heroTag: 'next_btn',
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    onPressed: _goNext,
                    child: const Icon(Icons.chevron_right, color: Colors.white),
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
                                  child: ListView.separated(
                                    controller: _tagsScrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _subfolders.length,
                                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final tag = _subfolders[index];
                                      return _CategoryPillChip(
                                        label: tag,
                                        onTap: () => _moveImageToFolder(tag),
                                      );
                                    },
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
    if (kIsWeb || path.startsWith('content://')) {
      return FutureBuilder<Uint8List?>(
        future: locator<FileService>().readFile(path),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            );
          }
          if (snapshot.hasError) {
            return const Icon(Icons.broken_image, size: 100, color: Colors.white);
          }
          return const CircularProgressIndicator(color: Colors.white);
        },
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RoundBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: const Color(0xFF242424).withValues(alpha: 0.9),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.15),
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
            : Colors.white.withValues(alpha: 0.15))
        : const Color(0xFF242424).withValues(alpha: 0.9);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Material(
            color: bgColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
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
  final VoidCallback onTap;

  const _CategoryPillChip({
    required this.label,
    required this.onTap,
  });

  @override
  State<_CategoryPillChip> createState() => _CategoryPillChipState();
}

class _CategoryPillChipState extends State<_CategoryPillChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _isHovered ? const Color(0xFF383838) : const Color(0xFF242424);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? const Color(0x66FFFFFF) : const Color(0x33FFFFFF),
          ),
        ),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: const Color(0xFFf89838).withValues(alpha: 0.35),
            highlightColor: const Color(0xFFf89838).withValues(alpha: 0.15),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 13,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: const TextStyle(
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
    );
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
        color: Colors.transparent,
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

  const _DetailRow({
    required this.label,
    required this.value,
    this.isPath = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;

    return Row(
      crossAxisAlignment: isPath ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
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
          child: Text(
            value,
            maxLines: isPath ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: isPath ? 'Lora' : 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogActionButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DialogActionButton({
    required this.label,
    required this.isPrimary,
    this.isDestructive = false,
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

    if (widget.isDestructive) {
      bg = widget.isPrimary
          ? (_isHovered ? const Color(0xFFDC2626) : const Color(0xFFEF4444))
          : (_isHovered ? const Color(0xFFEF4444).withValues(alpha: 0.15) : Colors.transparent);
      fg = widget.isPrimary ? Colors.white : const Color(0xFFEF4444);
      border = widget.isPrimary ? Colors.transparent : const Color(0xFFEF4444).withValues(alpha: 0.4);
    } else if (widget.isPrimary) {
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
            splashColor: widget.isDestructive
                ? Colors.white.withValues(alpha: 0.25)
                : sc.rippleColor,
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

