import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/locator.dart';
import '../services/picker_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/app_view_model.dart';
import 'theme_dialog.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _settingsService = locator<SettingsService>();
  final _appViewModel = locator<AppViewModel>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_onSettingsChanged);
    _appViewModel.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _appViewModel.removeListener(_onSettingsChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  bool _matchesQuery(List<String> keywords) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.toLowerCase().trim();
    return keywords.any((k) => k.toLowerCase().contains(q));
  }

  void _showThemePicker(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.2,
      ),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => ThemeDialog(
        currentTheme: _settingsService.themeMode,
        onThemeChanged: (mode) {
          _settingsService.setThemeMode(mode);
          _appViewModel.setThemeMode(mode);
        },
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  void _showFolderSortPicker(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sortOptions = <Map<String, dynamic>>[
      {
        'key': 'name_asc',
        'title': 'Name (A to Z)',
        'subtitle': 'Alphabetical order',
        'icon': Icons.sort_by_alpha_rounded,
      },
      {
        'key': 'name_desc',
        'title': 'Name (Z to A)',
        'subtitle': 'Reverse alphabetical order',
        'icon': Icons.sort_by_alpha_rounded,
      },
      {
        'key': 'items_desc',
        'title': 'Items (Most first)',
        'subtitle': 'Folders with most images at the top',
        'icon': Icons.photo_library_outlined,
      },
      {
        'key': 'items_asc',
        'title': 'Items (Fewest first)',
        'subtitle': 'Folders with fewest images at the top',
        'icon': Icons.photo_library_outlined,
      },
      {
        'key': 'date_desc',
        'title': 'Date (Newest first)',
        'subtitle': 'Recently modified folders first',
        'icon': Icons.calendar_today_outlined,
      },
      {
        'key': 'date_asc',
        'title': 'Date (Oldest first)',
        'subtitle': 'Oldest modified folders first',
        'icon': Icons.history_rounded,
      },
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 360,
                  constraints: const BoxConstraints(maxHeight: 520),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Folder Sort Order',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.close_rounded, size: 20, color: sc.muted),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: sortOptions.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
                          ),
                          itemBuilder: (context, index) {
                            final opt = sortOptions[index];
                            final isSelected = opt['key'] == _settingsService.folderSortOrder;

                            return InkWell(
                              onTap: () {
                                _settingsService.setFolderSortOrder(opt['key'] as String);
                                Navigator.of(ctx).pop();
                              },
                              borderRadius: BorderRadius.circular(10),
                              hoverColor: sc.menuHover,
                              splashColor: sc.rippleColor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      opt['icon'] as IconData,
                                      size: 19,
                                      color: isSelected ? sc.accent : sc.muted,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt['title'] as String,
                                            style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected
                                                  ? sc.accent
                                                  : (isDark ? Colors.white : Colors.black),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            opt['subtitle'] as String,
                                            style: TextStyle(
                                              fontFamily: 'Lora',
                                              fontSize: 11,
                                              color: sc.muted.withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: sc.accent,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
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
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _changePermanentScreenshotFolder() async {
    final dir = await PickerService.pickDirectory();
    if (dir != null) {
      _appViewModel.setPermanentScreenshotDir(dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;

    // Filter checks
    final showTheme = _matchesQuery(['theme', 'dark mode', 'light mode', 'appearance', 'color']);
    final showBlur = _matchesQuery(['blur', 'glassmorphism', 'transparency', 'disable blur', 'performance']);
    final showBatterySaver = _matchesQuery(['battery', 'blur', 'battery saver', 'low battery', 'performance', 'power']);
    final showBatterySlider = showBatterySaver;
    final showFolderSort = _matchesQuery(['folder', 'sort', 'folder sort order', 'tags', 'alphabetical', 'items', 'date']);
    final showBinAuth = _matchesQuery(['bin', 'security', 'auth', 'biometric', 'fingerprint', 'password', 'trash', 'lock']);
    final showStorage = _matchesQuery(['storage', 'folder', 'screenshot', 'permanent', 'path', 'browse']);

    final hasAppearance = showTheme || showBlur;
    final hasPerformance = showBatterySaver || showBatterySlider;
    final hasFolders = showFolderSort;
    final hasSecurity = showBinAuth;
    final hasStorage = showStorage;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // ── Top Navigation Bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Back button
                      _TopBarCircleButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const Spacer(),
                      // Close button (X) matching settings.png
                      _TopBarCircleButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // ── Search Bar matching settings.png ────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: sc.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: sc.muted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search settings...',
                              hintStyle: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 13,
                                color: sc.muted.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.clear_rounded,
                                size: 16,
                                color: sc.muted.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Settings Sections Scroll View ──────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // ── APPEARANCE ──────────────────────────────
                      if (hasAppearance) ...[
                        _buildSectionHeader('APPEARANCE', sc),
                        _buildCardContainer(
                          isDark: isDark,
                          sc: sc,
                          children: [
                            if (showTheme)
                              _SettingsTile(
                                icon: Icons.palette_outlined,
                                title: 'Theme',
                                subtitle: _getThemeLabel(_settingsService.themeMode),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getThemeShortLabel(_settingsService.themeMode),
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 12,
                                        color: sc.muted,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 19,
                                      color: sc.muted,
                                    ),
                                  ],
                                ),
                                onTap: () => _showThemePicker(context),
                              ),
                            if (showTheme && showBlur) _buildDivider(isDark),
                            if (showBlur)
                              _SettingsTile(
                                icon: Icons.blur_on_rounded,
                                title: 'Disable Blur',
                                subtitle: 'Turn off glassmorphism background blurs app-wide',
                                trailing: _buildSwitch(
                                  value: _settingsService.disableBlur,
                                  sc: sc,
                                  isDark: isDark,
                                  onChanged: (val) => _settingsService.setDisableBlur(val),
                                ),
                                onTap: () => _settingsService.setDisableBlur(!_settingsService.disableBlur),
                              ),
                          ],
                        ),
                      ],

                      // ── PERFORMANCE & BATTERY ───────────────────
                      if (hasPerformance) ...[
                        _buildSectionHeader('PERFORMANCE & BATTERY', sc),
                        _buildCardContainer(
                          isDark: isDark,
                          sc: sc,
                          children: [
                            if (showBatterySaver)
                              _SettingsTile(
                                icon: Icons.battery_saver_rounded,
                                title: 'Disable Blur on Low Battery',
                                subtitle: 'Turn off heavy blur shaders when battery drops below threshold',
                                trailing: _buildSwitch(
                                  value: _settingsService.disableBlurLowBattery,
                                  sc: sc,
                                  isDark: isDark,
                                  onChanged: (val) => _settingsService.setDisableBlurLowBattery(val),
                                ),
                                onTap: () => _settingsService.setDisableBlurLowBattery(
                                  !_settingsService.disableBlurLowBattery,
                                ),
                              ),
                            if (showBatterySaver && showBatterySlider) _buildDivider(isDark),
                            if (showBatterySlider)
                              _buildLowBatterySliderTile(
                                isDark: isDark,
                                sc: sc,
                                isEnabled: _settingsService.disableBlurLowBattery && !_settingsService.disableBlur,
                              ),
                          ],
                        ),
                      ],

                      // ── FOLDERS & TAGS ──────────────────────────
                      if (hasFolders) ...[
                        _buildSectionHeader('FOLDERS & TAGS', sc),
                        _buildCardContainer(
                          isDark: isDark,
                          sc: sc,
                          children: [
                            if (showFolderSort)
                              _SettingsTile(
                                icon: Icons.sort_rounded,
                                title: 'Folder Sort Order',
                                subtitle: SettingsService.getFolderSortLabel(_settingsService.folderSortOrder),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      SettingsService.getFolderSortLabel(_settingsService.folderSortOrder),
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 12,
                                        color: sc.muted,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 19,
                                      color: sc.muted,
                                    ),
                                  ],
                                ),
                                onTap: () => _showFolderSortPicker(context),
                              ),
                          ],
                        ),
                      ],

                      // ── SECURITY ────────────────────────────────
                      if (hasSecurity) ...[
                        _buildSectionHeader('SECURITY', sc),
                        _buildCardContainer(
                          isDark: isDark,
                          sc: sc,
                          children: [
                            if (showBinAuth)
                              _SettingsTile(
                                icon: Icons.security_rounded,
                                title: 'Bin Authentication',
                                subtitle: 'Require biometrics or device credentials to open Bin',
                                trailing: _buildSwitch(
                                  value: _settingsService.binAuthEnabled,
                                  sc: sc,
                                  isDark: isDark,
                                  onChanged: (val) => _settingsService.setBinAuthEnabled(val),
                                ),
                                onTap: () => _settingsService.setBinAuthEnabled(!_settingsService.binAuthEnabled),
                              ),
                          ],
                        ),
                      ],

                      // ── SYSTEM & STORAGE ────────────────────────
                      if (hasStorage) ...[
                        _buildSectionHeader('STORAGE & LOCATIONS', sc),
                        _buildCardContainer(
                          isDark: isDark,
                          sc: sc,
                          children: [
                            _SettingsTile(
                              icon: Icons.folder_special_rounded,
                              title: 'Screenshot Folder',
                              subtitle: _appViewModel.permanentScreenshotDir ?? 'Not configured (Tap to choose)',
                              trailing: Icon(
                                Icons.drive_file_move_outline,
                                size: 19,
                                color: sc.muted,
                              ),
                              onTap: _changePermanentScreenshotFolder,
                            ),
                            if (_appViewModel.screenshotDir != null) ...[
                              _buildDivider(isDark),
                              _SettingsTile(
                                icon: Icons.folder_open_rounded,
                                title: 'Active Browse Folder',
                                subtitle: _appViewModel.screenshotDir!,
                                trailing: null,
                                onTap: null,
                              ),
                            ],
                          ],
                        ),
                      ],

                      if (!hasAppearance && !hasPerformance && !hasFolders && !hasSecurity && !hasStorage)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'No settings found matching "$_searchQuery"',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 13,
                                color: sc.muted,
                              ),
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
    );
  }

  Widget _buildSectionHeader(String title, SnapgroveColors sc) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 22, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: sc.muted.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required SnapgroveColors sc,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: sc.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      endIndent: 12,
      color: isDark ? const Color(0x14FFFFFF) : const Color(0x0E000000),
    );
  }

  Widget _buildSwitch({
    required bool value,
    required SnapgroveColors sc,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Transform.scale(
      scale: 0.85,
      child: Switch(
        value: value,
        activeThumbColor: sc.accent,
        activeTrackColor: sc.accent.withValues(alpha: 0.35),
        inactiveThumbColor: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
        inactiveTrackColor: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return sc.accent;
          }
          return isDark ? const Color(0x33FFFFFF) : const Color(0x33000000);
        }),
        thumbIcon: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Icon(Icons.check, size: 12, color: Colors.black);
          }
          return null;
        }),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLowBatterySliderTile({
    required bool isDark,
    required SnapgroveColors sc,
    required bool isEnabled,
  }) {
    final threshold = _settingsService.lowBatteryThreshold;
    final effectiveColor = isEnabled ? (isDark ? Colors.white : Colors.black) : sc.muted.withValues(alpha: 0.5);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.battery_charging_full_rounded,
                  size: 20,
                  color: effectiveColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Low Battery Threshold',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: effectiveColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: threshold == 0 ? sc.muted.withValues(alpha: 0.15) : sc.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    threshold == 0 ? 'Off' : '${threshold.toInt()}%',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: threshold == 0 ? sc.muted : sc.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: sc.accent,
                inactiveTrackColor: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                thumbColor: sc.accent,
                overlayColor: sc.accent.withValues(alpha: 0.15),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: threshold.clamp(0.0, 100.0),
                min: 0,
                max: 100,
                label: threshold == 0 ? 'Off' : '${threshold.toInt()}%',
                onChanged: isEnabled
                    ? (val) {
                        _settingsService.setLowBatteryThreshold(val);
                      }
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Off (0%)',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: threshold == 0 ? FontWeight.w700 : FontWeight.normal,
                      color: threshold == 0 ? sc.accent : sc.muted.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    '35% (Default)',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: threshold == 35 ? FontWeight.w700 : FontWeight.normal,
                      color: threshold == 35 ? sc.accent : sc.muted.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    'On (100%)',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: threshold == 100 ? FontWeight.w700 : FontWeight.normal,
                      color: threshold == 100 ? sc.accent : sc.muted.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default (follows OS)';
      case ThemeMode.dark:
        return 'Dark mode';
      case ThemeMode.light:
        return 'Light mode';
    }
  }

  String _getThemeShortLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;

    return InkWell(
      onTap: onTap,
      hoverColor: sc.menuHover,
      splashColor: sc.rippleColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 12,
                      color: sc.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBarCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0x22FFFFFF) : const Color(0x0F000000),
              border: Border.all(
                color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
