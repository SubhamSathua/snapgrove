import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/app_constants.dart';
import '../theme/app_theme.dart';
import '../theme/snap_symbols.dart';

class SourceCodeView extends StatefulWidget {
  const SourceCodeView({super.key});

  @override
  State<SourceCodeView> createState() => _SourceCodeViewState();
}

class _SourceCodeViewState extends State<SourceCodeView> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    _isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (_isMobile) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) {
                setState(() => _loadingProgress = progress / 100.0);
              }
            },
            onPageStarted: (url) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (url) {
              if (mounted) setState(() => _isLoading = false);
            },
          ),
        )
        ..loadRequest(Uri.parse(AppConstants.repoUrl));
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $url')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching browser: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF9F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Circular Back and Circular "Open in Browser" action
            _buildTopBar(context, sc, isDark),

            // Main Rounded WebView Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141414) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isMobile && _webViewController != null
                        ? Stack(
                            children: [
                              WebViewWidget(controller: _webViewController!),
                              if (_isLoading)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: LinearProgressIndicator(
                                    value: _loadingProgress > 0 ? _loadingProgress : null,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(sc.accent),
                                    minHeight: 2.5,
                                  ),
                                ),
                            ],
                          )
                        : _buildDesktopCard(context, sc, isDark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF141414) : Colors.white).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000),
          ),
        ),
      ),
      child: Row(
        children: [
          // Circular Back Button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                splashColor: sc.rippleColor,
                child: Center(
                  child: Icon(
                    SnapSymbols.arrow_back_ios_new,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GitHub Repository',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'SubhamSathua/snapgrove',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11.5,
                    color: sc.muted,
                  ),
                ),
              ],
            ),
          ),
          // Circular Open in Browser Button
          Tooltip(
            message: 'Open in Browser',
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _launchUrl(context, AppConstants.repoUrl),
                  splashColor: sc.rippleColor,
                  child: Center(
                    child: Icon(
                      SnapSymbols.open_in_new,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCard(BuildContext context, SnapgroveColors sc, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: sc.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: sc.accent.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Icon(
                    SnapSymbols.code,
                    size: 32,
                    color: sc.accent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'SubhamSathua/snapgrove',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.appTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 14,
                  color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTag('main', sc, isDark),
                  const SizedBox(width: 8),
                  _buildTag('MIT License', sc, isDark),
                  const SizedBox(width: 8),
                  _buildTag(AppConstants.appVersionName, sc, isDark),
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sc.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(SnapSymbols.open_in_new, size: 18),
                label: const Text(
                  'Open on GitHub',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => _launchUrl(context, AppConstants.repoUrl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFDDDDDD) : const Color(0xFF444444),
        ),
      ),
    );
  }
}
