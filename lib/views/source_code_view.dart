import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_constants.dart';
import '../theme/app_theme.dart';
import '../theme/snap_symbols.dart';

class SourceCodeView extends StatelessWidget {
  const SourceCodeView({super.key});

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

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label copied to clipboard',
          style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final contentMax = width >= 900 ? 760.0 : (width >= 600 ? 640.0 : double.infinity);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF9F9FB),
      body: SafeArea(
        child: SelectionArea(
          child: Column(
            children: [
              // Top Bar with "Open with" action button at top
              _buildTopBar(context, sc, isDark),

              // Content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMax),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Repo Card
                        _buildRepoCard(context, sc, isDark),
                        const SizedBox(height: 16),

                        // Clone Command Card
                        _buildCloneCard(context, sc, isDark),
                        const SizedBox(height: 16),

                        // Tech Stack & Architecture Card
                        _buildTechStackCard(sc, isDark),
                        const SizedBox(height: 16),

                        // Community & Links Card
                        _buildCommunityCard(context, sc, isDark),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                  child: SvgPicture.asset(
                    'assets/icons/Back-Btn.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      isDark ? Colors.white : Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Source Code',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'github.com/SubhamSathua/snapgrove',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 12,
                    color: sc.muted,
                  ),
                ),
              ],
            ),
          ),
          // Top Action Button: "Open with" / "Open in Browser"
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: sc.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _launchUrl(context, AppConstants.repoUrl),
            icon: const Icon(SnapSymbols.open_in_new_rounded, size: 14),
            label: const Text(
              'Open with',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoCard(BuildContext context, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x14000000),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222222) : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(
                  'assets/icons/github.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    isDark ? Colors.white : Colors.black,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SubhamSathua / snapgrove',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Public Repository • main branch',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Snapgrove is an open-source, high-performance screenshot & image organizer crafted with Flutter. Built for rapid folder triage, batch SAF management, and zero telemetry.',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 13.5,
              height: 1.55,
              color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag('Flutter 3.x', sc, isDark),
              _buildTag('Dart 3.x', sc, isDark),
              _buildTag('SAF Batching', sc, isDark),
              _buildTag('MVVM + GetIt', sc, isDark),
              _buildTag('MIT License', sc, isDark),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _launchUrl(context, AppConstants.repoUrl),
              icon: SvgPicture.asset(
                'assets/icons/github.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.white : Colors.black,
                  BlendMode.srcIn,
                ),
              ),
              label: const Text(
                'View Repository on GitHub',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloneCard(BuildContext context, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clone Repository',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use git to clone and run Snapgrove locally on Windows, Android, or Web:',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 12.5,
              color: sc.muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090909) : const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0x20FFFFFF) : const Color(0x15000000),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'git clone ${AppConstants.repoCloneUrl}',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: sc.accent,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _copyToClipboard(
                    context,
                    'git clone ${AppConstants.repoCloneUrl}',
                    'Clone command',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      SnapSymbols.copy_rounded,
                      size: 16,
                      color: sc.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechStackCard(SnapgroveColors sc, bool isDark) {
    const modules = [
      {'path': 'lib/viewmodels/', 'desc': 'ChangeNotifier MVVM state management'},
      {'path': 'lib/services/', 'desc': 'SAF helper, thumbnail manager, platform storage'},
      {'path': 'lib/views/', 'desc': 'Gallery grid, responsive layout, full preview'},
      {'path': 'lib/theme/', 'desc': 'SnapgroveColors extension, typography tokens'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Architecture & Structure',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...modules.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      color: sc.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    m['path']!,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m['desc']!,
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 12,
                        color: sc.muted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommunityCard(BuildContext context, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contribute & Issues',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Found a bug or have a feature idea? Contributions, pull requests, and feedback are always welcome.',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 12.5,
              color: sc.muted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _launchUrl(context, AppConstants.issuesUrl),
                  child: const Text(
                    'Report Issue',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _launchUrl(context, AppConstants.releasesUrl),
                  child: const Text(
                    'Releases',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
        ),
      ),
    );
  }
}
