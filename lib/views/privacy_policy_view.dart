import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_constants.dart';
import '../theme/app_theme.dart';
import '../theme/snap_symbols.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
              // Top Bar
              _buildTopBar(context, sc, isDark),

              // Content Area
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMax),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Hero Header Card
                        _buildHeroCard(sc, isDark),
                        const SizedBox(height: 20),

                        // Section Cards
                        ...AppConstants.privacySections.map((sec) {
                          return _buildSectionCard(
                            sc: sc,
                            isDark: isDark,
                            title: sec['title'] as String,
                            content: sec['content'] as String,
                          );
                        }),

                        const SizedBox(height: 12),

                        // Footer / Repo link card
                        _buildFooterCard(sc, isDark),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Last updated: ${AppConstants.privacyLastUpdated}',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 12,
                    color: sc.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: sc.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sc.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  SnapSymbols.shield_person,
                  size: 13,
                  color: sc.accent,
                ),
                const SizedBox(width: 5),
                Text(
                  '100% Offline',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sc.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x14000000),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                  color: sc.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  SnapSymbols.shield_person,
                  size: 22,
                  color: sc.accent,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Data Stays On Your Device',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'No Cloud • No Tracking • No Accounts',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Snapgrove is engineered with privacy as a foundational principle. We believe photo and screenshot organizers should never require an internet connection or send telemetry home. Everything happens directly on your machine.',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 14,
              height: 1.55,
              color: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF3C3C3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required SnapgroveColors sc,
    required bool isDark,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 13.5,
              height: 1.55,
              color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterCard(SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F1F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x28FFFFFF) : const Color(0x18000000),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                SnapSymbols.code,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 8),
              const Text(
                'Inspect the Source Code',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Transparency is verifiable. You can view, audit, and contribute to the complete codebase on GitHub.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 12.5,
              color: sc.muted,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(color: sc.accent.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => _launchUrl(AppConstants.repoUrl),
            child: const Text(
              'Visit GitHub Repository',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
