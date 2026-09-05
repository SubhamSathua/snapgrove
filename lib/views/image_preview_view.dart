import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import '../core/locator.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';

class ImagePreviewView extends StatefulWidget {
  final List<String> files;
  final int initialIndex;

  const ImagePreviewView({
    super.key,
    required this.files,
    required this.initialIndex,
  });

  @override
  State<ImagePreviewView> createState() => _ImagePreviewViewState();
}

class _ImagePreviewViewState extends State<ImagePreviewView> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isDesktopOrWeb = false;

  // Zoom and Drag state
  late TransformationController _transformController;
  double _currentZoom = 1.0;
  Timer? _zoomCapsuleTimer;
  bool _showZoomCapsule = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _isDesktopOrWeb = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    _transformController = TransformationController();
    _transformController.addListener(_onZoomChanged);
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
    
    // Ignore tiny layout changes that happen when page changes
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
      // Reset zoom to 1.0
      _setZoom(1.0);
    } else {
      // Zoom into tapped point
      _setZoom(2.0, details.localPosition);
    }
  }

  void _goNext() {
    if (_currentIndex < widget.files.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final currentPath = widget.files[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/Back-Btn.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          p.basename(currentPath).replaceAll('%2F', '/').split('/').last,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
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
            PageView.builder(
              controller: _pageController,
              itemCount: widget.files.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _transformController.value = Matrix4.identity(); // reset zoom on page change
                });
              },
              itemBuilder: (context, index) {
                final path = widget.files[index];
                return Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      // Handle shift + scroll for zoom on Desktop/Web
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
                      cursor: _isDesktopOrWeb ? SystemMouseCursors.grab : MouseCursor.defer,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1.0,
                        maxScale: 5.0,
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

            // Left Arrow for Web/Win
            if (_isDesktopOrWeb && _currentIndex > 0)
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

            // Right Arrow for Web/Win
            if (_isDesktopOrWeb && _currentIndex < widget.files.length - 1)
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
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showZoomCapsule ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showZoomCapsule,
                    child: Container(
                      height: 48, // STRICT HEIGHT to prevent vertical stretching into a circle
                      width: _isDesktopOrWeb ? 400 : null,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(24), // Perfect pill shape for 48px height
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_currentZoom * 100).toInt()}%',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              color: Colors.white,
                              fontSize: 14,
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
                                activeColor: sc.accent,
                                inactiveColor: Colors.white30,
                                onChanged: (val) {
                                  _setZoom(val);
                                },
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
