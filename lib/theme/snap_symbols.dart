// ignore_for_file: constant_identifier_names

/// Material Symbols Rounded icon constants for Snapgrove.
///
/// Uses the bundled `MaterialSymbolsRounded` variable font (Fill=0, weight=400).
/// Codepoints are identical to Material Icons; only the fontFamily differs.
///
/// Usage:
/// ```dart
/// Icon(SnapSymbols.folder)
/// ```
library;

import 'package:flutter/widgets.dart';

abstract final class SnapSymbols {
  static const String _family = 'MaterialSymbolsRounded';

  // ── Navigation ────────────────────────────────────────────────────────────
  static const IconData home = IconData(0xe88a, fontFamily: _family);
  static const IconData arrow_back = IconData(0xe5c4, fontFamily: _family);
  static const IconData arrow_forward = IconData(0xe5c8, fontFamily: _family);
  static const IconData chevron_left = IconData(0xe5cb, fontFamily: _family);
  static const IconData chevron_right = IconData(0xe5cc, fontFamily: _family);
  static const IconData expand_less = IconData(0xe5ce, fontFamily: _family);
  static const IconData expand_more = IconData(0xe5cf, fontFamily: _family);
  static const IconData menu = IconData(0xe5d2, fontFamily: _family);
  static const IconData close = IconData(0xe5cd, fontFamily: _family);
  static const IconData more_vert = IconData(0xe5d4, fontFamily: _family);
  static const IconData more_horiz = IconData(0xe5d3, fontFamily: _family);

  // ── Folders ───────────────────────────────────────────────────────────────
  static const IconData folder = IconData(0xe2c7, fontFamily: _family);
  static const IconData folder_open = IconData(0xe2c8, fontFamily: _family);
  static const IconData folder_special = IconData(0xe617, fontFamily: _family);
  static const IconData create_new_folder =
      IconData(0xe2cc, fontFamily: _family);
  static const IconData drive_folder_upload =
      IconData(0xe9a3, fontFamily: _family);

  // ── Files & Media ─────────────────────────────────────────────────────────
  static const IconData image = IconData(0xe3f4, fontFamily: _family);
  static const IconData photo = IconData(0xe410, fontFamily: _family);
  static const IconData photo_library = IconData(0xe413, fontFamily: _family);
  static const IconData collections = IconData(0xe3b6, fontFamily: _family);

  // ── Actions ───────────────────────────────────────────────────────────────
  static const IconData add = IconData(0xe145, fontFamily: _family);
  static const IconData remove = IconData(0xe15b, fontFamily: _family);
  static const IconData edit = IconData(0xe3c9, fontFamily: _family);
  static const IconData delete = IconData(0xe872, fontFamily: _family);
  static const IconData bin = delete;
  static const IconData delete_forever = IconData(0xe92b, fontFamily: _family);
  static const IconData share = IconData(0xe80d, fontFamily: _family);
  static const IconData download = IconData(0xf090, fontFamily: _family);
  static const IconData upload = IconData(0xf09b, fontFamily: _family);
  static const IconData copy_all = IconData(0xe2a2, fontFamily: _family);
  static const IconData content_cut = IconData(0xe14e, fontFamily: _family);
  static const IconData content_paste = IconData(0xe14f, fontFamily: _family);
  static const IconData drive_file_move =
      IconData(0xe675, fontFamily: _family);
  static const IconData undo = IconData(0xe166, fontFamily: _family);
  static const IconData redo = IconData(0xe15a, fontFamily: _family);
  static const IconData refresh = IconData(0xe5d5, fontFamily: _family);
  static const IconData open_in_new = IconData(0xe89e, fontFamily: _family);

  // ── Selection ─────────────────────────────────────────────────────────────
  static const IconData check = IconData(0xe876, fontFamily: _family);
  static const IconData check_circle = IconData(0xe86c, fontFamily: _family);
  static const IconData check_box = IconData(0xe834, fontFamily: _family);
  static const IconData check_box_outline_blank =
      IconData(0xe835, fontFamily: _family);
  static const IconData radio_button_unchecked =
      IconData(0xe836, fontFamily: _family);
  static const IconData radio_button_checked =
      IconData(0xe837, fontFamily: _family);
  static const IconData select_all = IconData(0xe162, fontFamily: _family);

  // ── Search & Filter ───────────────────────────────────────────────────────
  static const IconData search = IconData(0xe8b6, fontFamily: _family);
  static const IconData filter_list = IconData(0xe152, fontFamily: _family);
  static const IconData sort = IconData(0xe164, fontFamily: _family);
  static const IconData tune = IconData(0xe429, fontFamily: _family);

  // ── View & Layout ─────────────────────────────────────────────────────────
  static const IconData grid_view = IconData(0xe9b0, fontFamily: _family);
  static const IconData view_list = IconData(0xe8ef, fontFamily: _family);
  static const IconData view_module = IconData(0xe8f0, fontFamily: _family);
  static const IconData view_compact = IconData(0xe42b, fontFamily: _family);
  static const IconData fullscreen = IconData(0xe5d0, fontFamily: _family);
  static const IconData fullscreen_exit =
      IconData(0xe5d1, fontFamily: _family);
  static const IconData zoom_in = IconData(0xe8ff, fontFamily: _family);
  static const IconData zoom_out = IconData(0xe900, fontFamily: _family);
  static const IconData fit_screen = IconData(0xea10, fontFamily: _family);

  // ── Visibility ────────────────────────────────────────────────────────────
  static const IconData visibility = IconData(0xe8f4, fontFamily: _family);
  static const IconData visibility_off = IconData(0xe8f5, fontFamily: _family);
  static const IconData hide_image = IconData(0xf022, fontFamily: _family);

  // ── Info & Status ─────────────────────────────────────────────────────────
  static const IconData info = IconData(0xe88e, fontFamily: _family);
  static const IconData info_outline = IconData(0xe88f, fontFamily: _family);
  static const IconData warning = IconData(0xe002, fontFamily: _family);
  static const IconData error = IconData(0xe000, fontFamily: _family);
  static const IconData error_outline = IconData(0xe001, fontFamily: _family);
  static const IconData help = IconData(0xe887, fontFamily: _family);
  static const IconData help_outline = IconData(0xe8fd, fontFamily: _family);

  // ── Settings & Preferences ────────────────────────────────────────────────
  static const IconData settings = IconData(0xe8b8, fontFamily: _family);
  static const IconData tune_settings = IconData(0xe8b8, fontFamily: _family);
  static const IconData dark_mode = IconData(0xe51c, fontFamily: _family);
  static const IconData light_mode = IconData(0xe518, fontFamily: _family);
  static const IconData palette = IconData(0xe40a, fontFamily: _family);
  static const IconData display_settings =
      IconData(0xeb97, fontFamily: _family);

  // ── Battery ───────────────────────────────────────────────────────────────
  static const IconData battery_saver = IconData(0xefef, fontFamily: _family);
  static const IconData battery_charging = IconData(0xe1a3, fontFamily: _family);
  static const IconData battery_charging_full = battery_charging;
  static const IconData battery_full = IconData(0xe1a4, fontFamily: _family);
  static const IconData battery_alert = IconData(0xe19c, fontFamily: _family);

  // ── Misc UI ───────────────────────────────────────────────────────────────
  static const IconData star = IconData(0xe838, fontFamily: _family);
  static const IconData star_border = IconData(0xe83a, fontFamily: _family);
  static const IconData bookmark = IconData(0xe866, fontFamily: _family);
  static const IconData label = IconData(0xe892, fontFamily: _family);
  static const IconData tag = IconData(0xe9f0, fontFamily: _family);
  static const IconData lock = IconData(0xe897, fontFamily: _family);
  static const IconData lock_open = IconData(0xe898, fontFamily: _family);
  static const IconData key = IconData(0xe73c, fontFamily: _family);
  static const IconData fingerprint = IconData(0xe90d, fontFamily: _family);
  static const IconData cloud = IconData(0xe2bd, fontFamily: _family);
  static const IconData cloud_done = IconData(0xe2bf, fontFamily: _family);
  static const IconData cloud_off = IconData(0xe2c1, fontFamily: _family);
  static const IconData link = IconData(0xe157, fontFamily: _family);
  static const IconData broken_image = IconData(0xe3ad, fontFamily: _family);
  static const IconData panorama_fish_eye =
      IconData(0xe40c, fontFamily: _family);
  static const IconData drag_handle = IconData(0xe25d, fontFamily: _family);
  static const IconData swap_vert = IconData(0xe8d5, fontFamily: _family);
}
