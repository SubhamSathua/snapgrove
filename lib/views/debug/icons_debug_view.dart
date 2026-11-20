import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../theme/snap_symbols.dart';

/// Item in the Material 3 Symbol Catalog.
class SymbolCatalogItem {
  final String name;
  final String category;

  const SymbolCatalogItem(this.name, this.category);
}

/// Curated catalog of 130+ Material 3 Symbols across 11 categories,
/// matching `assets/fonts/material3-symbols-tester.html`.
const List<SymbolCatalogItem> kCuratedSymbols = [
  // Navigation (18)
  SymbolCatalogItem('home', 'Navigation'),
  SymbolCatalogItem('menu', 'Navigation'),
  SymbolCatalogItem('close', 'Navigation'),
  SymbolCatalogItem('arrow_back', 'Navigation'),
  SymbolCatalogItem('arrow_forward', 'Navigation'),
  SymbolCatalogItem('arrow_upward', 'Navigation'),
  SymbolCatalogItem('arrow_downward', 'Navigation'),
  SymbolCatalogItem('chevron_left', 'Navigation'),
  SymbolCatalogItem('chevron_right', 'Navigation'),
  SymbolCatalogItem('expand_more', 'Navigation'),
  SymbolCatalogItem('expand_less', 'Navigation'),
  SymbolCatalogItem('more_vert', 'Navigation'),
  SymbolCatalogItem('more_horiz', 'Navigation'),
  SymbolCatalogItem('apps', 'Navigation'),
  SymbolCatalogItem('dashboard', 'Navigation'),
  SymbolCatalogItem('widgets', 'Navigation'),
  SymbolCatalogItem('fullscreen', 'Navigation'),
  SymbolCatalogItem('open_in_new', 'Navigation'),

  // Actions (30)
  SymbolCatalogItem('search', 'Actions'),
  SymbolCatalogItem('settings', 'Actions'),
  SymbolCatalogItem('tune', 'Actions'),
  SymbolCatalogItem('favorite', 'Actions'),
  SymbolCatalogItem('star', 'Actions'),
  SymbolCatalogItem('bookmark', 'Actions'),
  SymbolCatalogItem('delete', 'Actions'),
  SymbolCatalogItem('edit', 'Actions'),
  SymbolCatalogItem('add', 'Actions'),
  SymbolCatalogItem('add_circle', 'Actions'),
  SymbolCatalogItem('remove', 'Actions'),
  SymbolCatalogItem('check', 'Actions'),
  SymbolCatalogItem('check_circle', 'Actions'),
  SymbolCatalogItem('done_all', 'Actions'),
  SymbolCatalogItem('refresh', 'Actions'),
  SymbolCatalogItem('sync', 'Actions'),
  SymbolCatalogItem('download', 'Actions'),
  SymbolCatalogItem('upload', 'Actions'),
  SymbolCatalogItem('share', 'Actions'),
  SymbolCatalogItem('content_copy', 'Actions'),
  SymbolCatalogItem('content_paste', 'Actions'),
  SymbolCatalogItem('visibility', 'Actions'),
  SymbolCatalogItem('visibility_off', 'Actions'),
  SymbolCatalogItem('lock', 'Actions'),
  SymbolCatalogItem('lock_open', 'Actions'),
  SymbolCatalogItem('key', 'Actions'),
  SymbolCatalogItem('login', 'Actions'),
  SymbolCatalogItem('logout', 'Actions'),
  SymbolCatalogItem('filter_list', 'Actions'),
  SymbolCatalogItem('sort', 'Actions'),

  // Communication (14)
  SymbolCatalogItem('mail', 'Communication'),
  SymbolCatalogItem('inbox', 'Communication'),
  SymbolCatalogItem('send', 'Communication'),
  SymbolCatalogItem('chat', 'Communication'),
  SymbolCatalogItem('forum', 'Communication'),
  SymbolCatalogItem('comment', 'Communication'),
  SymbolCatalogItem('call', 'Communication'),
  SymbolCatalogItem('videocam', 'Communication'),
  SymbolCatalogItem('notifications', 'Communication'),
  SymbolCatalogItem('notifications_active', 'Communication'),
  SymbolCatalogItem('notifications_off', 'Communication'),
  SymbolCatalogItem('campaign', 'Communication'),
  SymbolCatalogItem('alternate_email', 'Communication'),
  SymbolCatalogItem('contacts', 'Communication'),

  // Media (16)
  SymbolCatalogItem('play_arrow', 'Media'),
  SymbolCatalogItem('play_circle', 'Media'),
  SymbolCatalogItem('pause', 'Media'),
  SymbolCatalogItem('stop', 'Media'),
  SymbolCatalogItem('skip_next', 'Media'),
  SymbolCatalogItem('skip_previous', 'Media'),
  SymbolCatalogItem('volume_up', 'Media'),
  SymbolCatalogItem('volume_off', 'Media'),
  SymbolCatalogItem('mic', 'Media'),
  SymbolCatalogItem('mic_off', 'Media'),
  SymbolCatalogItem('headphones', 'Media'),
  SymbolCatalogItem('music_note', 'Media'),
  SymbolCatalogItem('photo_camera', 'Media'),
  SymbolCatalogItem('image', 'Media'),
  SymbolCatalogItem('movie', 'Media'),
  SymbolCatalogItem('cast', 'Media'),

  // Files (16)
  SymbolCatalogItem('folder', 'Files'),
  SymbolCatalogItem('folder_open', 'Files'),
  SymbolCatalogItem('description', 'Files'),
  SymbolCatalogItem('article', 'Files'),
  SymbolCatalogItem('draft', 'Files'),
  SymbolCatalogItem('attach_file', 'Files'),
  SymbolCatalogItem('link', 'Files'),
  SymbolCatalogItem('cloud', 'Files'),
  SymbolCatalogItem('cloud_upload', 'Files'),
  SymbolCatalogItem('cloud_download', 'Files'),
  SymbolCatalogItem('cloud_done', 'Files'),
  SymbolCatalogItem('code', 'Files'),
  SymbolCatalogItem('terminal', 'Files'),
  SymbolCatalogItem('data_object', 'Files'),
  SymbolCatalogItem('database', 'Files'),
  SymbolCatalogItem('print', 'Files'),

  // Device (14)
  SymbolCatalogItem('smartphone', 'Device'),
  SymbolCatalogItem('laptop_mac', 'Device'),
  SymbolCatalogItem('desktop_windows', 'Device'),
  SymbolCatalogItem('tablet', 'Device'),
  SymbolCatalogItem('watch', 'Device'),
  SymbolCatalogItem('wifi', 'Device'),
  SymbolCatalogItem('bluetooth', 'Device'),
  SymbolCatalogItem('battery_full', 'Device'),
  SymbolCatalogItem('battery_charging_full', 'Device'),
  SymbolCatalogItem('bolt', 'Device'),
  SymbolCatalogItem('dark_mode', 'Device'),
  SymbolCatalogItem('light_mode', 'Device'),
  SymbolCatalogItem('memory', 'Device'),
  SymbolCatalogItem('qr_code_2', 'Device'),

  // Social (12)
  SymbolCatalogItem('person', 'Social'),
  SymbolCatalogItem('account_circle', 'Social'),
  SymbolCatalogItem('group', 'Social'),
  SymbolCatalogItem('groups', 'Social'),
  SymbolCatalogItem('thumb_up', 'Social'),
  SymbolCatalogItem('thumb_down', 'Social'),
  SymbolCatalogItem('mood', 'Social'),
  SymbolCatalogItem('public', 'Social'),
  SymbolCatalogItem('school', 'Social'),
  SymbolCatalogItem('work', 'Social'),
  SymbolCatalogItem('rocket_launch', 'Social'),
  SymbolCatalogItem('auto_awesome', 'Social'),

  // Status (8)
  SymbolCatalogItem('info', 'Status'),
  SymbolCatalogItem('help', 'Status'),
  SymbolCatalogItem('warning', 'Status'),
  SymbolCatalogItem('error', 'Status'),
  SymbolCatalogItem('verified', 'Status'),
  SymbolCatalogItem('shield', 'Status'),
  SymbolCatalogItem('schedule', 'Status'),
  SymbolCatalogItem('calendar_today', 'Status'),

  // Commerce (5)
  SymbolCatalogItem('shopping_cart', 'Commerce'),
  SymbolCatalogItem('shopping_bag', 'Commerce'),
  SymbolCatalogItem('credit_card', 'Commerce'),
  SymbolCatalogItem('payments', 'Commerce'),
  SymbolCatalogItem('storefront', 'Commerce'),

  // Maps (5)
  SymbolCatalogItem('location_on', 'Maps'),
  SymbolCatalogItem('map', 'Maps'),
  SymbolCatalogItem('explore', 'Maps'),
  SymbolCatalogItem('directions_car', 'Maps'),
  SymbolCatalogItem('flight', 'Maps'),

  // Design (1)
  SymbolCatalogItem('palette', 'Design'),
];

/// Known symbols directly exposed by [SnapSymbols] constants.
const Set<String> kSnapSymbolsCatalog = {
  'home',
  'arrow_back',
  'arrow_forward',
  'chevron_left',
  'chevron_right',
  'expand_less',
  'expand_more',
  'keyboard_arrow_down',
  'keyboard_arrow_up',
  'keyboard_arrow_right',
  'keyboard_arrow_left',
  'menu',
  'close',
  'clear',
  'more_vert',
  'more_horiz',
  'folder',
  'folder_open',
  'folder_special',
  'create_new_folder',
  'snippet_folder',
  'drive_folder_upload',
  'image',
  'photo',
  'photo_library',
  'collections',
  'preview',
  'add',
  'remove',
  'edit',
  'delete',
  'bin',
  'delete_forever',
  'delete_sweep',
  'share',
  'download',
  'upload',
  'content_copy',
  'copy_all',
  'content_cut',
  'content_paste',
  'drive_file_move',
  'drive_file_rename_outline',
  'restore',
  'history',
  'undo',
  'redo',
  'refresh',
  'open_in_new',
  'check',
  'check_circle',
  'check_box',
  'check_box_outline_blank',
  'radio_button_unchecked',
  'radio_button_checked',
  'select_all',
  'deselect',
  'checklist',
  'done_all',
  'search',
  'search_off',
  'filter_list',
  'sort',
  'sort_by_alpha',
  'tune',
  'grid_view',
  'view_list',
  'view_module',
  'view_compact',
  'fullscreen',
  'fullscreen_exit',
  'zoom_in',
  'zoom_out',
  'fit_screen',
  'visibility',
  'visibility_off',
  'hide_image',
  'info',
  'info_outline',
  'warning',
  'error',
  'error_outline',
  'help',
  'help_outline',
  'settings',
  'settings_outlined',
  'tune_settings',
  'dark_mode',
  'light_mode',
  'palette',
  'palette_outlined',
  'display_settings',
  'blur_on',
  'battery_saver',
  'battery_charging',
  'battery_charging_full',
  'battery_full',
  'battery_alert',
  'star',
  'star_border',
  'bookmark',
  'label',
  'tag',
  'lock',
  'lock_open',
  'security',
  'shield',
  'shield_outlined',
  'key',
  'fingerprint',
  'cloud',
  'cloud_done',
  'cloud_off',
  'link',
  'broken_image',
  'broken_image_outlined',
  'calendar_today',
  'calendar_today_outlined',
  'panorama_fish_eye',
  'drag_handle',
  'swap_vert',
};

/// Interactive Material 3 Symbols tester modeling `assets/fonts/material3-symbols-tester.html`.
class IconsDebugView extends StatefulWidget {
  const IconsDebugView({super.key});

  @override
  State<IconsDebugView> createState() => _IconsDebugViewState();
}

class _IconsDebugViewState extends State<IconsDebugView> {
  // Catalog state
  final List<SymbolCatalogItem> _customSymbols = [];
  String _selectedSymbol = 'home';
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customLigatureController = TextEditingController();

  // Axes state
  double _fill = 0.0;
  double _wght = 400.0;
  double _grad = 0.0;
  double _opsz = 24.0;

  // Visual Controls state
  double _fontSize = 32.0;
  Color _color = const Color(0xFF1B1F27);
  Color _backgroundColor = const Color(0xFFFFFFFF);
  bool _syncOpsz = false;
  bool _hoverFill = true;
  bool _includeListInJson = false;

  // Available categories
  static const List<String> _categories = [
    'All',
    'Navigation',
    'Actions',
    'Communication',
    'Media',
    'Files',
    'Device',
    'Social',
    'Status',
    'Commerce',
    'Maps',
    'Design',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _customLigatureController.dispose();
    super.dispose();
  }

  List<SymbolCatalogItem> _getAllSymbols() {
    return [..._customSymbols, ...kCuratedSymbols];
  }

  List<SymbolCatalogItem> _getFilteredSymbols() {
    final query = _searchQuery.trim().toLowerCase();
    return _getAllSymbols().where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _resetAll() {
    setState(() {
      _fill = 0.0;
      _wght = 400.0;
      _grad = 0.0;
      _opsz = 24.0;
      _fontSize = 32.0;
      _color = const Color(0xFF1B1F27);
      _backgroundColor = const Color(0xFFFFFFFF);
      _syncOpsz = false;
      _hoverFill = true;
      _includeListInJson = false;
      _selectedSymbol = 'home';
      _selectedCategory = 'All';
      _searchQuery = '';
      _searchController.clear();
      _customLigatureController.clear();
    });
    _showToast('Reset to default state');
  }

  void _addCustomLigature() {
    final val = _customLigatureController.text.trim().toLowerCase();
    if (val.isEmpty) return;

    if (!_customSymbols.any((s) => s.name == val) && !kCuratedSymbols.any((s) => s.name == val)) {
      _customSymbols.insert(0, SymbolCatalogItem(val, 'Custom'));
    }
    setState(() {
      _selectedSymbol = val;
      _customLigatureController.clear();
    });
    _showToast('Testing "$val"');
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast('Copied $label to clipboard');
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
        ),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _colorToHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  String _colorToFlutterHex(Color c) {
    final a = (c.a * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    return '0x$a$r$g$b';
  }

  Color? _parseHexColor(String raw) {
    String hex = raw.trim().replaceFirst('#', '').replaceFirst('0x', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final val = int.tryParse(hex, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  String _buildFlutterSnippet() {
    final fillStr = _fill % 1 == 0 ? _fill.toStringAsFixed(1) : _fill.toStringAsFixed(2);
    final wghtStr = _wght.toStringAsFixed(1);
    final gradStr = _grad.toStringAsFixed(1);
    final opszStr = _opsz.toStringAsFixed(1);
    final sizeStr = _fontSize.toStringAsFixed(1);
    final hexCode = _colorToFlutterHex(_color);

    final buffer = StringBuffer();
    buffer.writeln("Text(");
    buffer.writeln("  '$_selectedSymbol',");
    buffer.writeln("  style: TextStyle(");
    buffer.writeln("    fontFamily: 'MaterialSymbolsRounded',");
    buffer.writeln("    fontSize: $sizeStr,");
    buffer.writeln("    color: Color($hexCode),");
    buffer.writeln("    fontVariations: [");
    buffer.writeln("      FontVariation('FILL', $fillStr),");
    buffer.writeln("      FontVariation('wght', $wghtStr),");
    buffer.writeln("      FontVariation('GRAD', $gradStr),");
    buffer.writeln("      FontVariation('opsz', $opszStr),");
    buffer.writeln("    ],");
    buffer.writeln("  ),");
    buffer.write(")");

    if (kSnapSymbolsCatalog.contains(_selectedSymbol)) {
      buffer.writeln("\n\n// Or using SnapSymbols constant:");
      buffer.writeln("Icon(");
      buffer.writeln("  SnapSymbols.$_selectedSymbol,");
      buffer.writeln("  size: $sizeStr,");
      buffer.writeln("  color: Color($hexCode),");
      buffer.write(")");
    }

    return buffer.toString();
  }

  Map<String, dynamic> _buildJsonObject() {
    final fvs =
        "'FILL' ${_fill % 1 == 0 ? _fill.toStringAsFixed(0) : _fill.toStringAsFixed(2)}, 'wght' ${_wght.round()}, 'GRAD' ${_grad.round()}, 'opsz' ${_opsz.round()}";
    final all = _getAllSymbols();
    final found = all.firstWhere(
      (s) => s.name == _selectedSymbol,
      orElse: () => SymbolCatalogItem(_selectedSymbol, 'Custom'),
    );
    final filtered = _getFilteredSymbols();

    final payload = <String, dynamic>{
      'font': {
        'file': 'assets/fonts/MaterialSymbolsRounded.ttf',
        'family': 'MaterialSymbolsRounded',
        'loaded': true,
      },
      'selectedSymbol': {
        'ligature': _selectedSymbol,
        'category': found.category,
      },
      'variationSettings': {
        'FILL': _fill,
        'wght': _wght,
        'GRAD': _grad,
        'opsz': _opsz,
        'cssValue': fvs,
      },
      'style': {
        'fontSize': '${_fontSize.round()}px',
        'color': _colorToHex(_color),
        'backgroundColor': _colorToHex(_backgroundColor),
        'syncOpszWithFontSize': _syncOpsz,
        'hoverFillAnimation': _hoverFill,
      },
      'snippets': {
        'flutter': _buildFlutterSnippet(),
        if (kSnapSymbolsCatalog.contains(_selectedSymbol))
          'snapSymbols':
              'Icon(SnapSymbols.$_selectedSymbol, size: ${_fontSize.toStringAsFixed(1)}, color: Color(${_colorToFlutterHex(_color)}))',
        'html': '<span class="material-symbols-rounded">$_selectedSymbol</span>',
        'css':
            ".material-symbols-rounded { font-family: 'Material Symbols Rounded'; font-size: ${_fontSize.round()}px; color: ${_colorToHex(_color)}; font-variation-settings: $fvs; }",
      },
      'catalog': {
        'totalSymbols': all.length,
        'visibleSymbols': filtered.length,
        'activeCategory': _selectedCategory,
        'searchQuery': _searchQuery,
        if (_includeListInJson) 'symbols': filtered.map((s) => s.name).toList(),
      },
    };

    return payload;
  }

  void _showEditJsonDialog() {
    final currentJson = const JsonEncoder.withIndent('  ').convert(_buildJsonObject());
    final editorController = TextEditingController(text: currentJson);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text(
            'Edit / Import JSON',
            style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16),
          ),
          content: SizedBox(
            width: 500,
            child: TextField(
              controller: editorController,
              maxLines: 14,
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste or edit configuration JSON...',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                try {
                  final data = jsonDecode(editorController.text) as Map<String, dynamic>;
                  if (data.containsKey('variationSettings')) {
                    final vs = data['variationSettings'] as Map<String, dynamic>;
                    if (vs['FILL'] != null) _fill = (vs['FILL'] as num).toDouble();
                    if (vs['wght'] != null) _wght = (vs['wght'] as num).toDouble();
                    if (vs['GRAD'] != null) _grad = (vs['GRAD'] as num).toDouble();
                    if (vs['opsz'] != null) _opsz = (vs['opsz'] as num).toDouble();
                  }
                  if (data.containsKey('style')) {
                    final st = data['style'] as Map<String, dynamic>;
                    if (st['fontSize'] != null) {
                      final parsed = double.tryParse(st['fontSize'].toString().replaceAll('px', ''));
                      if (parsed != null) _fontSize = parsed;
                    }
                    if (st['color'] != null) {
                      final c = _parseHexColor(st['color'].toString());
                      if (c != null) _color = c;
                    }
                    if (st['backgroundColor'] != null) {
                      final c = _parseHexColor(st['backgroundColor'].toString());
                      if (c != null) _backgroundColor = c;
                    }
                    if (st['syncOpszWithFontSize'] != null) {
                      _syncOpsz = st['syncOpszWithFontSize'] as bool;
                    }
                    if (st['hoverFillAnimation'] != null) {
                      _hoverFill = st['hoverFillAnimation'] as bool;
                    }
                  }
                  if (data.containsKey('selectedSymbol')) {
                    final sym = data['selectedSymbol'];
                    if (sym is Map<String, dynamic> && sym['ligature'] != null) {
                      _selectedSymbol = sym['ligature'].toString();
                    } else if (sym is String) {
                      _selectedSymbol = sym;
                    }
                  }
                  setState(() {});
                  Navigator.of(dialogCtx).pop();
                  _showToast('JSON Configuration Applied');
                } catch (e) {
                  _showToast('Invalid JSON: $e');
                }
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // UI Building Blocks
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPresetButton({
    required String label,
    required VoidCallback onTap,
    Key? key,
    bool isActive = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
              : Theme.of(context).dividerColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'JetBrains Mono',
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildControlsPanel({VoidCallback? onStateChanged}) {
    void notify() {
      setState(() {});
      onStateChanged?.call();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Axes Sliders & Presets',
                style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            IconButton(
              key: const Key('panel_reset_all_btn'),
              tooltip: 'Reset All',
              icon: const Icon(SnapSymbols.refresh, size: 18),
              onPressed: _resetAll,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // FILL
        Row(
          children: [
            const Expanded(
              child: Text('FILL', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12)),
            ),
            Text(
              _fill.toStringAsFixed(2),
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        Slider(
          key: const Key('fill_slider'),
          value: _fill,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          onChanged: (val) {
            _fill = val;
            notify();
          },
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildPresetButton(
              key: const Key('preset_fill_0'),
              label: '0 Outlined',
              isActive: _fill == 0.0,
              onTap: () {
                _fill = 0.0;
                notify();
              },
            ),
            _buildPresetButton(
              key: const Key('preset_fill_0.5'),
              label: '0.5 Half',
              isActive: (_fill - 0.5).abs() < 0.01,
              onTap: () {
                _fill = 0.5;
                notify();
              },
            ),
            _buildPresetButton(
              key: const Key('preset_fill_1'),
              label: '1 Filled',
              isActive: _fill == 1.0,
              onTap: () {
                _fill = 1.0;
                notify();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // wght
        Row(
          children: [
            const Expanded(
              child: Text('wght', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12)),
            ),
            Text(
              '${_wght.round()}',
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        Slider(
          key: const Key('wght_slider'),
          value: _wght,
          min: 100.0,
          max: 700.0,
          divisions: 60,
          onChanged: (val) {
            _wght = val;
            notify();
          },
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [100, 200, 300, 400, 500, 600, 700].map((w) {
            return _buildPresetButton(
              key: Key('preset_wght_$w'),
              label: '$w',
              isActive: _wght.round() == w,
              onTap: () {
                _wght = w.toDouble();
                notify();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // GRAD
        Row(
          children: [
            const Expanded(
              child: Text('GRAD', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12)),
            ),
            Text(
              '${_grad.round()}',
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        Slider(
          key: const Key('grad_slider'),
          value: _grad,
          min: -50.0,
          max: 200.0,
          divisions: 250,
          onChanged: (val) {
            _grad = val;
            notify();
          },
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildPresetButton(
              key: const Key('preset_grad_-25'),
              label: '-25 Dark',
              isActive: _grad.round() == -25,
              onTap: () {
                _grad = -25.0;
                notify();
              },
            ),
            _buildPresetButton(
              key: const Key('preset_grad_0'),
              label: '0 Normal',
              isActive: _grad.round() == 0,
              onTap: () {
                _grad = 0.0;
                notify();
              },
            ),
            _buildPresetButton(
              key: const Key('preset_grad_200'),
              label: '200 Emphasis',
              isActive: _grad.round() == 200,
              onTap: () {
                _grad = 200.0;
                notify();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // opsz
        Row(
          children: [
            const Expanded(
              child: Text('opsz (Optical Size)', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12)),
            ),
            Text(
              '${_opsz.round()}dp',
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        Slider(
          key: const Key('opsz_slider'),
          value: _opsz,
          min: 20.0,
          max: 48.0,
          divisions: 28,
          onChanged: (val) {
            _opsz = val;
            _syncOpsz = false;
            notify();
          },
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [20, 24, 40, 48].map((sz) {
            return _buildPresetButton(
              key: Key('preset_opsz_$sz'),
              label: '${sz}dp',
              isActive: _opsz.round() == sz,
              onTap: () {
                _opsz = sz.toDouble();
                _syncOpsz = false;
                notify();
              },
            );
          }).toList(),
        ),

        const Divider(height: 28),

        // Visual & Interaction
        const Text(
          'Visual Controls',
          style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),

        // Font Size
        Row(
          children: [
            const Expanded(
              child: Text('Font Size', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12)),
            ),
            Text(
              '${_fontSize.round()}px',
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        Slider(
          key: const Key('font_size_slider'),
          value: _fontSize,
          min: 16.0,
          max: 88.0,
          divisions: 72,
          onChanged: (val) {
            _fontSize = val;
            if (_syncOpsz) {
              _opsz = val.clamp(20.0, 48.0);
            }
            notify();
          },
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [20, 24, 32, 48, 64].map((sz) {
            return _buildPresetButton(
              key: Key('preset_size_$sz'),
              label: '${sz}px',
              isActive: _fontSize.round() == sz,
              onTap: () {
                _fontSize = sz.toDouble();
                if (_syncOpsz) {
                  _opsz = _fontSize.clamp(20.0, 48.0);
                }
                notify();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Colors
        const Text('Color Presets', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildPresetButton(
              key: const Key('preset_theme_light'),
              label: 'Light',
              onTap: () {
                _color = const Color(0xFF1B1F27);
                _backgroundColor = const Color(0xFFFFFFFF);
                _grad = 0.0;
                notify();
              },
            ),
            _buildPresetButton(
              key: const Key('preset_theme_dark'),
              label: 'Dark (GRAD -25)',
              onTap: () {
                _color = const Color(0xFFE3E8F0);
                _backgroundColor = const Color(0xFF14171F);
                _grad = -25.0;
                notify();
              },
            ),
            _buildPresetButton(
              key: const Key('preset_theme_m3blue'),
              label: 'M3 Primary',
              onTap: () {
                _color = const Color(0xFF0B57D0);
                _backgroundColor = const Color(0xFFE8F0FE);
                _grad = 0.0;
                notify();
              },
            ),
            _buildPresetButton(
              key: const Key('preset_theme_m3tonal'),
              label: 'M3 Tonal',
              onTap: () {
                _color = const Color(0xFF4F378B);
                _backgroundColor = const Color(0xFFF3EDF7);
                _grad = 0.0;
                notify();
              },
            ),
            _buildPresetButton(
              key: const Key('preset_theme_accent'),
              label: 'Snapgrove Accent',
              onTap: () {
                _color = const Color(0xFFFFFFFF);
                _backgroundColor = SnapgroveColors.light.accent;
                _grad = 0.0;
                notify();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Swatches for Foreground & Background
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Icon Color', style: TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono')),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _colorToHex(_color),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Card Surface', style: TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono')),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _colorToHex(_backgroundColor),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const Divider(height: 24),

        // Toggles
        SwitchListTile(
          key: const Key('toggle_sync_opsz'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-sync opsz with font size', style: TextStyle(fontSize: 12)),
          value: _syncOpsz,
          onChanged: (val) {
            _syncOpsz = val;
            if (_syncOpsz) {
              _opsz = _fontSize.clamp(20.0, 48.0);
            }
            notify();
          },
        ),
        SwitchListTile(
          key: const Key('toggle_hover_fill'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Animate FILL on hover/tap', style: TextStyle(fontSize: 12)),
          value: _hoverFill,
          onChanged: (val) {
            _hoverFill = val;
            notify();
          },
        ),
        SwitchListTile(
          key: const Key('toggle_include_list'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Include list in JSON', style: TextStyle(fontSize: 12)),
          value: _includeListInJson,
          onChanged: (val) {
            _includeListInJson = val;
            notify();
          },
        ),
      ],
    );
  }

  Widget _buildSpotlightCard() {
    final all = _getAllSymbols();
    final found = all.firstWhere(
      (s) => s.name == _selectedSymbol,
      orElse: () => SymbolCatalogItem(_selectedSymbol, 'Custom'),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large preview box
              Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _selectedSymbol,
                    key: const Key('spotlight_symbol_text'),
                    style: TextStyle(
                      fontFamily: 'MaterialSymbolsRounded',
                      fontSize: 64,
                      color: _color,
                      fontVariations: [
                        FontVariation('FILL', _fill),
                        FontVariation('wght', _wght),
                        FontVariation('GRAD', _grad),
                        FontVariation('opsz', _opsz),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Meta details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _selectedSymbol,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            found.category,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('copy_name_btn'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(SnapSymbols.content_copy, size: 14),
                          label: const Text('Copy Name', style: TextStyle(fontSize: 11)),
                          onPressed: () => _copyToClipboard(_selectedSymbol, 'Symbol name'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Optical size comparison (opsz: 20, 24, 40, 48 with current FILL ${_fill.toStringAsFixed(1)}, wght ${_wght.round()}, GRAD ${_grad.round()}):',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Optical size comparison strip
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [20, 24, 40, 48].map((sz) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 52,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _selectedSymbol,
                            style: TextStyle(
                              fontFamily: 'MaterialSymbolsRounded',
                              fontSize: sz.toDouble(),
                              color: _color,
                              fontVariations: [
                                FontVariation('FILL', _fill),
                                FontVariation('wght', _wght),
                                FontVariation('GRAD', _grad),
                                FontVariation('opsz', sz.toDouble()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'opsz $sz',
                      style: const TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndCustomBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final searchField = TextField(
          key: const Key('search_input'),
          controller: _searchController,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search 130+ symbols (e.g., home, search, star)...',
            hintStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(SnapSymbols.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(SnapSymbols.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (val) {
            setState(() => _searchQuery = val);
          },
        );

        final customFieldAndBtn = Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('custom_symbol_input'),
                controller: _customLigatureController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Custom ligature (e.g. rocket_launch)',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (_) => _addCustomLigature(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              key: const Key('add_custom_btn'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: _addCustomLigature,
              child: const Text('Add & Test', style: TextStyle(fontSize: 12)),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: 8),
              customFieldAndBtn,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: searchField),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: customFieldAndBtn),
          ],
        );
      },
    );
  }

  Widget _buildCategoryBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('category_chip_$cat'),
              label: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedCategory = cat);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCountRow() {
    final filtered = _getFilteredSymbols();
    final all = _getAllSymbols();
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          'Showing ${filtered.length} of ${all.length} symbols',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        Text(
          'Click any tile to inspect & update',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolGrid() {
    final symbols = _getFilteredSymbols();

    if (symbols.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          'No symbols matched "$_searchQuery". Use the custom ligature box above to test any Material Symbol name.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute responsive column count
        final width = constraints.maxWidth;
        final crossAxisCount = (width / 95).clamp(3, 10).floor();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: symbols.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final item = symbols[index];
            final isSelected = item.name == _selectedSymbol;

            return _SymbolCardTile(
              item: item,
              isSelected: isSelected,
              fontSize: _fontSize,
              color: _color,
              surfaceColor: _backgroundColor,
              fill: _fill,
              wght: _wght,
              grad: _grad,
              opsz: _opsz,
              hoverFill: _hoverFill,
              onTap: () {
                setState(() {
                  _selectedSymbol = item.name;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildJsonAndSnippetPanel() {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_buildJsonObject());
    final flutterSnippet = _buildFlutterSnippet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text(
              'JSON & Flutter Code',
              style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 13),
            ),
            OutlinedButton(
              onPressed: _showEditJsonDialog,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Edit / Import', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Live JSON
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text('Live JSON Configuration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ElevatedButton.icon(
              key: const Key('copy_json_btn'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(SnapSymbols.content_copy, size: 13),
              label: const Text('Copy JSON', style: TextStyle(fontSize: 11)),
              onPressed: () => _copyToClipboard(jsonStr, 'JSON'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, height: 1.35),
            ),
          ),
        ),

        const Divider(height: 24),

        // Flutter Code Snippet
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text('Flutter Code Snippet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ElevatedButton.icon(
              key: const Key('copy_code_btn'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(SnapSymbols.code, size: 13),
              label: const Text('Copy Code', style: TextStyle(fontSize: 11)),
              onPressed: () => _copyToClipboard(flutterSnippet, 'Flutter code'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          ),
          child: SelectableText(
            flutterSnippet,
            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, height: 1.35),
          ),
        ),
      ],
    );
  }

  void _openMobileControlsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      _buildControlsPanel(
                        onStateChanged: () {
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openMobileJsonSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _buildJsonAndSnippetPanel(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPC = constraints.maxWidth >= 900;

        if (isPC) {
          // PC Layout (width >= 900)
          return Scaffold(
            key: const Key('icons_debug_pc_layout'),
            appBar: AppBar(
              title: const Text(
                'Material 3 Symbols Tester',
                style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 16),
              ),
              actions: [
                OutlinedButton.icon(
                  key: const Key('reset_all_btn'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(SnapSymbols.refresh, size: 16),
                  label: const Text('Reset All', style: TextStyle(fontSize: 12)),
                  onPressed: _resetAll,
                ),
                const SizedBox(width: 16),
              ],
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left 300px: Controls
                SizedBox(
                  width: 300,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildControlsPanel(),
                  ),
                ),
                const VerticalDivider(width: 1),

                // Center: Spotlight + Search + Grid
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSpotlightCard(),
                        const SizedBox(height: 16),
                        _buildSearchAndCustomBar(),
                        const SizedBox(height: 12),
                        _buildCategoryBar(),
                        const SizedBox(height: 10),
                        _buildCountRow(),
                        const SizedBox(height: 12),
                        _buildSymbolGrid(),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),

                // Right 340px: JSON Preview & Flutter Snippets
                SizedBox(
                  width: 340,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildJsonAndSnippetPanel(),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Layout (width < 900)
          return Scaffold(
            key: const Key('icons_debug_mobile_layout'),
            appBar: AppBar(
              title: const Text(
                'Symbols Tester',
                style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16),
              ),
              actions: [
                IconButton(
                  key: const Key('mobile_controls_btn'),
                  tooltip: 'Controls',
                  icon: const Icon(SnapSymbols.tune),
                  onPressed: () => _openMobileControlsSheet(context),
                ),
                IconButton(
                  key: const Key('mobile_json_btn'),
                  tooltip: 'Code & JSON',
                  icon: const Icon(SnapSymbols.code),
                  onPressed: () => _openMobileJsonSheet(context),
                ),
                IconButton(
                  key: const Key('reset_all_btn'),
                  tooltip: 'Reset All',
                  icon: const Icon(SnapSymbols.refresh),
                  onPressed: _resetAll,
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSpotlightCard(),
                  const SizedBox(height: 12),
                  _buildSearchAndCustomBar(),
                  const SizedBox(height: 10),
                  _buildCategoryBar(),
                  const SizedBox(height: 10),
                  _buildCountRow(),
                  const SizedBox(height: 12),
                  _buildSymbolGrid(),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}

/// A tile in the symbol grid supporting hover animation for FILL.
class _SymbolCardTile extends StatefulWidget {
  final SymbolCatalogItem item;
  final bool isSelected;
  final double fontSize;
  final Color color;
  final Color surfaceColor;
  final double fill;
  final double wght;
  final double grad;
  final double opsz;
  final bool hoverFill;
  final VoidCallback onTap;

  const _SymbolCardTile({
    required this.item,
    required this.isSelected,
    required this.fontSize,
    required this.color,
    required this.surfaceColor,
    required this.fill,
    required this.wght,
    required this.grad,
    required this.opsz,
    required this.hoverFill,
    required this.onTap,
  });

  @override
  State<_SymbolCardTile> createState() => _SymbolCardTileState();
}

class _SymbolCardTileState extends State<_SymbolCardTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveFill = (widget.hoverFill && _isHovered) ? 1.0 : widget.fill;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hoverFill) setState(() => _isHovered = true);
        },
        onTapUp: (_) {
          if (widget.hoverFill) setState(() => _isHovered = false);
        },
        onTapCancel: () {
          if (widget.hoverFill) setState(() => _isHovered = false);
        },
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? primaryColor
                  : Theme.of(context).dividerColor.withValues(alpha: _isHovered ? 0.35 : 0.15),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected || _isHovered
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: widget.isSelected ? 0.15 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.item.name,
                      style: TextStyle(
                        fontFamily: 'MaterialSymbolsRounded',
                        fontSize: widget.fontSize.clamp(16.0, 48.0),
                        color: widget.color,
                        fontVariations: [
                          FontVariation('FILL', effectiveFill),
                          FontVariation('wght', widget.wght),
                          FontVariation('GRAD', widget.grad),
                          FontVariation('opsz', widget.opsz),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                  color: widget.isSelected
                      ? primaryColor
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
