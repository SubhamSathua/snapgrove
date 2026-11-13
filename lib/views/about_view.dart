import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_constants.dart';
import '../theme/app_theme.dart';
import '../theme/snap_symbols.dart';
import 'privacy_policy_view.dart';
import 'licenses_view.dart';
import 'source_code_view.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

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
                      // Hero Branding Card
                      _buildHeroBranding(context, sc, isDark),
                      const SizedBox(height: 20),

                      // Highlights Title
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 10),
                        child: Text(
                          'Core Highlights',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),

                      // Key Feature Cards Grid / Column
                      ...AppConstants.keyFeatures.map((feat) {
                        return _buildFeatureCard(
                          sc: sc,
                          isDark: isDark,
                          title: feat['title']!,
                          description: feat['description']!,
                          iconPath: feat['icon']!,
                        );
                      }),
                      const SizedBox(height: 12),

                      // Quick Navigation Section
                      _buildQuickLinksCard(context, sc, isDark),
                      const SizedBox(height: 16),

                      // Creator & Credits Card
                      _buildAuthorCard(sc, isDark),
                      const SizedBox(height: 32),
                    ],
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
          const Expanded(
            child: Text(
              'About Snapgrove',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: sc.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sc.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              AppConstants.appVersionName,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sc.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBranding(BuildContext context, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x14000000),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // App Logo (assets/logo/logo.png - already has corner radius)
          Image.asset(
            'assets/logo/logo.png',
            width: 72,
            height: 72,
            errorBuilder: (context, error, stackTrace) => Icon(
              SnapSymbols.photo_library_outlined,
              size: 48,
              color: sc.accent,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppConstants.appTagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 14,
              color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge('Build ${AppConstants.appBuildNumber}', sc, isDark),
              const SizedBox(width: 8),
              _buildBadge(AppConstants.licenseType, sc, isDark),
              const SizedBox(width: 8),
              _buildBadge('Flutter 3.x', sc, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required SnapgroveColors sc,
    required bool isDark,
    required String title,
    required String description,
    required String iconPath,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: sc.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              iconPath,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(sc.accent, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark ? const Color(0xFFBBBBBB) : const Color(0xFF555555),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinksCard(BuildContext context, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            'Documents & Code',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildLinkTile(
            title: 'Privacy Policy',
            subtitle: '100% offline & local data handling details',
            svgPath: 'assets/icons/shield.svg',
            sc: sc,
            isDark: isDark,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyView()),
              );
            },
          ),
          const Divider(height: 12, thickness: 0.5),
          _buildLinkTile(
            title: 'Open Source Licenses',
            subtitle: 'Third-party libraries & license attributions',
            svgPath: 'assets/icons/license.svg',
            sc: sc,
            isDark: isDark,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LicensesView()),
              );
            },
          ),
          const Divider(height: 12, thickness: 0.5),
          _buildLinkTile(
            title: 'Source Code & Architecture',
            subtitle: 'GitHub repository, clone URLs, and modules',
            svgPath: 'assets/icons/github.svg',
            sc: sc,
            isDark: isDark,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SourceCodeView()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile({
    required String title,
    required String subtitle,
    required String svgPath,
    required SnapgroveColors sc,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            SvgPicture.asset(
              svgPath,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white70 : Colors.black87,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 11.5,
                      color: sc.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              SnapSymbols.chevron_right_rounded,
              size: 20,
              color: sc.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorCard(SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sc.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: sc.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                'SS',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: sc.accent,
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
                  'Created by Subham Sathua',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Crafted with focus on speed, aesthetics, and privacy.',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 12,
                    color: sc.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'GitHub Profile',
            icon: SvgPicture.asset(
              'assets/icons/github.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white : Colors.black,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => _launchUrl(AppConstants.authorGithub),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242424) : const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFDCDCDC) : const Color(0xFF444444),
        ),
      ),
    );
  }
}
