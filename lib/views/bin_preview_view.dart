import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/locator.dart';
import '../services/bin_service.dart';
import '../services/notification_service.dart';
import '../services/share/share_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_blur.dart';
import '../viewmodels/app_view_model.dart';
import '../viewmodels/bin_view_model.dart';

class BinPreviewView extends StatefulWidget {
  final BinViewModel viewModel;
  final int initialIndex;
  final String? targetDirectory;

  const BinPreviewView({
    super.key,
    required this.viewModel,
    required this.initialIndex,
    this.targetDirectory,
  });

  @override
  State<BinPreviewView> createState() => _BinPreviewViewState();
}

class _BinPreviewViewState extends State<BinPreviewView> {
  late PageController _pageController;
  late List<BinFileInfo> _files;
  late int _currentIndex;
  bool _isFullScreen = false;

  late TransformationController _transformController;
  double _currentZoom = 1.0;
  Timer? _zoomCapsuleTimer;
  bool _showZoomCapsule = false;

  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _files = List<BinFileInfo>.from(widget.viewModel.files);
    _currentIndex = widget.initialIndex.clamp(0, _files.isNotEmpty ? _files.length - 1 : 0);
    _pageController = PageController(initialPage: _currentIndex);
    _transformController = TransformationController();
    _transformController.addListener(_onZoomChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAdjacent(_currentIndex);
    });
  }

  void _preloadAdjacent(int index) {
    for (final offset in [-1, 0, 1]) {
      final target = index + offset;
      if (target >= 0 && target < _files.length) {
        final file = _files[target];
        if (!_imageCache.containsKey(file.path)) {
          locator<BinService>().readDecryptedFile(file.path).then((bytes) {
            if (bytes != null && mounted) {
              setState(() {
                _imageCache[file.path] = bytes;
              });
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
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

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  Future<void> _shareCurrentImage() async {
    if (_files.isEmpty) return;
    final file = _files[_currentIndex];
    Uint8List? bytes = _imageCache[file.path];
    bytes ??= await locator<BinService>().readDecryptedFile(file.path);

    if (bytes != null) {
      final shared = await locator<ShareService>().shareImageFile(
        filePath: file.path,
        fileName: file.originalName,
        bytes: bytes,
      );

      if (!shared) {
        await Clipboard.setData(ClipboardData(text: file.originalName));
        locator<NotificationService>().showSnackBar('File name copied to clipboard');
      }
    }
  }

  Future<void> _restoreCurrentImage() async {
    if (_files.isEmpty) return;
    final file = _files[_currentIndex];
    String? target = widget.targetDirectory;
    if (target == null || target.isEmpty) {
      if (locator.isRegistered<AppViewModel>()) {
        final appVm = locator<AppViewModel>();
        target = appVm.screenshotDir ?? appVm.permanentScreenshotDir;
      }
    }
    final success = await widget.viewModel.restoreSingleFile(file.path, targetDirectory: target);
    if (success && mounted) {
      setState(() {
        _files.removeAt(_currentIndex);
        if (_files.isEmpty) {
          Navigator.of(context).pop();
        } else if (_currentIndex >= _files.length) {
          _currentIndex = _files.length - 1;
        }
      });
    }
  }

  Future<void> _confirmDeleteCurrentImage() async {
    if (_files.isEmpty) return;
    final file = _files[_currentIndex];
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
                    'Are you sure you want to permanently delete "${file.originalName}"? This action cannot be undone.',
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
                      _BinActionButton(
                        label: 'Cancel',
                        isPrimary: false,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 10),
                      _BinActionButton(
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

    if (confirmed == true && mounted) {
      final success = await widget.viewModel.deleteSingleFile(file.path);
      if (success && mounted) {
        setState(() {
          _files.removeAt(_currentIndex);
          if (_files.isEmpty) {
            Navigator.of(context).pop();
          } else if (_currentIndex >= _files.length) {
            _currentIndex = _files.length - 1;
          }
        });
      }
    }
  }

  Future<void> _showInfoDialog() async {
    if (_files.isEmpty) return;
    final file = _files[_currentIndex];
    final sc = context.snapgroveColors;

    int? imgWidth;
    int? imgHeight;

    try {
      Uint8List? bytes = _imageCache[file.path];
      bytes ??= await locator<BinService>().readDecryptedFile(file.path);
      if (bytes != null) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        imgWidth = frame.image.width;
        imgHeight = frame.image.height;
        frame.image.dispose();
      }
    } catch (_) {}

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
              width: MediaQuery.of(ctx).size.width * 0.9 > 400 ? 400 : MediaQuery.of(ctx).size.width * 0.9,
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
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFf89838).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.info_outline, color: Color(0xFFf89838), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Bin Item Details',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _InfoRow(label: 'File name', value: file.originalName),
                  _InfoRow(label: 'Folder', value: file.folderName),
                  if (file.parentBreadcrumb != null && file.parentBreadcrumb!.isNotEmpty)
                    _InfoRow(label: 'Origin breadcrumb', value: file.parentBreadcrumb!),
                  _InfoRow(label: 'Restores to', value: file.parentBreadcrumb != null ? '${file.parentBreadcrumb}/${file.folderName}' : file.folderName),
                  _InfoRow(label: 'Size', value: file.formattedSize),
                  _InfoRow(label: 'Dimensions', value: imgWidth != null ? '$imgWidth × $imgHeight px' : 'Calculating...'),
                  _InfoRow(label: 'Deleted on', value: file.formattedDeletedDate),
                  _InfoRow(
                    label: 'Days remaining',
                    value: '${file.daysRemaining} day${file.daysRemaining == 1 ? '' : 's'} before auto-delete',
                    valueColor: file.daysRemaining <= 5 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _BinActionButton(
                      label: 'Close',
                      isPrimary: false,
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
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
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text('No images in bin', style: TextStyle(color: Colors.white, fontFamily: 'JetBrains Mono')),
        ),
      );
    }

    final currentFile = _files[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView with zoom
          GestureDetector(
            onTap: _toggleFullScreen,
            onDoubleTapDown: _handleDoubleTap,
            onDoubleTap: () {},
            child: PageView.builder(
              controller: _pageController,
              itemCount: _files.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _transformController.value = Matrix4.identity();
                  _currentZoom = 1.0;
                });
                _preloadAdjacent(index);
              },
              itemBuilder: (context, index) {
                final file = _files[index];
                return InteractiveViewer(
                  transformationController: _currentIndex == index ? _transformController : null,
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Center(
                    child: _imageCache.containsKey(file.path)
                        ? Image.memory(
                            _imageCache[file.path]!,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                          )
                        : FutureBuilder<Uint8List?>(
                            future: locator<BinService>().readDecryptedFile(file.path),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                _imageCache[file.path] = snapshot.data!;
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, stack) =>
                                      const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                                );
                              }
                              return const Center(
                                child: CircularProgressIndicator(color: Color(0xFFff2a7b), strokeWidth: 2),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
          ),

          // Zoom capsule badge
          if (_showZoomCapsule)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: AppBlur.filter(sigmaX: 10, sigmaY: 10)!,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      color: AppBlur.getBackgroundColor(Colors.black54),
                      child: Text(
                        '${(_currentZoom * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'JetBrains Mono',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top Header Bar
          if (!_isFullScreen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Back Button
                      _BlurCircleButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      // Title & Days Remaining
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentFile.originalName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${currentFile.daysRemaining} days left in bin',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                color: currentFile.daysRemaining <= 5
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Action buttons
                      _BlurCircleButton(
                        icon: Icons.info_outline,
                        onTap: _showInfoDialog,
                      ),
                      const SizedBox(width: 8),
                      _BlurCircleButton(
                        icon: Icons.share_outlined,
                        onTap: _shareCurrentImage,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Action Bar
          if (!_isFullScreen)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Permanently Delete Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _confirmDeleteCurrentImage,
                          icon: const Icon(Icons.delete_forever, color: Colors.white, size: 20),
                          label: const Text(
                            'Delete',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Restore Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _restoreCurrentImage,
                          icon: const Icon(Icons.restore, color: Colors.black, size: 20),
                          label: const Text(
                            'Restore',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2fad5c),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlurCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BlurCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: AppBlur.filter(sigmaX: 10, sigmaY: 10)!,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppBlur.getBackgroundColor(Colors.black.withValues(alpha: 0.5)),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                color: sc.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BinActionButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback onTap;

  const _BinActionButton({
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
