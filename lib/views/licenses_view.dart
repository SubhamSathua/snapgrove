import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_constants.dart';
import '../theme/app_theme.dart';

class LicensesView extends StatefulWidget {
  const LicensesView({super.key});

  @override
  State<LicensesView> createState() => _LicensesViewState();
}

class _LicensesViewState extends State<LicensesView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedPackages = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
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

    final filteredPackages = AppConstants.openSourcePackages.where((pkg) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = pkg['name']?.toLowerCase() ?? '';
      final desc = pkg['description']?.toLowerCase() ?? '';
      final lic = pkg['license']?.toLowerCase() ?? '';
      final author = pkg['author']?.toLowerCase() ?? '';
      return name.contains(q) || desc.contains(q) || lic.contains(q) || author.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF9F9FB),
      body: SafeArea(
        child: SelectionArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(context, sc, isDark),

              // Search Bar
              _buildSearchBar(sc, isDark, contentMax),

              // Package List
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMax),
                    child: filteredPackages.isEmpty
                        ? _buildEmptyState(sc, isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredPackages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == filteredPackages.length) {
                                return _buildLicenseFooter(sc, isDark);
                              }
                              final pkg = filteredPackages[index];
                              return _buildPackageCard(pkg, sc, isDark);
                            },
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
                  'Open Source Licenses',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  '${AppConstants.openSourcePackages.length} dependencies listed',
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
                SvgPicture.asset(
                  'assets/icons/license.svg',
                  width: 13,
                  height: 13,
                  colorFilter: ColorFilter.mode(sc.accent, BlendMode.srcIn),
                ),
                const SizedBox(width: 5),
                Text(
                  'OSL',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

  Widget _buildSearchBar(SnapgroveColors sc, bool isDark, double contentMax) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMax),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191919) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0x22FFFFFF) : const Color(0x14000000),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search packages or licenses...',
                hintStyle: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 13,
                  color: sc.muted.withValues(alpha: 0.8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageCard(Map<String, String> pkg, SnapgroveColors sc, bool isDark) {
    final name = pkg['name'] ?? '';
    final version = pkg['version'] ?? '';
    final license = pkg['license'] ?? '';
    final author = pkg['author'] ?? '';
    final description = pkg['description'] ?? '';
    final text = pkg['text'] ?? '';
    final isExpanded = _expandedPackages.contains(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? sc.accent.withValues(alpha: 0.35)
              : (isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPackages.remove(name);
                } else {
                  _expandedPackages.add(name);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF242424) : const Color(0xFFEEEEEE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                version,
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10.5,
                                  color: sc.muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: sc.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                license,
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: sc.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFBBBBBB) : const Color(0xFF555555),
                          ),
                        ),
                        if (author.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'By $author',
                            style: TextStyle(
                              fontFamily: 'Lora',
                              fontSize: 11,
                              color: sc.muted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: sc.muted,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible License Text
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF7F7F9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Full License Text',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: sc.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () => _copyToClipboard(text, '$name license'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            'Copy',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              color: sc.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF080808) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0x18FFFFFF) : const Color(0x12000000),
                      ),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11.5,
                        height: 1.45,
                        color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(SnapgroveColors sc, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: sc.muted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No matching packages found',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: sc.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching with a different package name or license keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 12.5,
                color: sc.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseFooter(SnapgroveColors sc, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : const Color(0xFFF1F1F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Snapgrove itself is licensed under the ${AppConstants.licenseType}.',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All third-party libraries and fonts remain the property of their respective authors and copyright holders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 11.5,
              color: sc.muted,
            ),
          ),
        ],
      ),
    );
  }
}
