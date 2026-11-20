import 'package:flutter/material.dart';
import '../../models/folder_node.dart';
import '../../theme/app_theme.dart';
import '../../theme/snap_symbols.dart';

class FolderTreePickerModal extends StatefulWidget {
  final FolderNode? rootNode;
  final String? currentFolderName; // to disable/indicate current location
  final List<String> currentSelectedTags; // all tags current selected items already belong to
  final ValueChanged<String> onFolderSelected; // returns relPath or 'ROOT'

  const FolderTreePickerModal({
    super.key,
    required this.rootNode,
    this.currentFolderName,
    this.currentSelectedTags = const [],
    required this.onFolderSelected,
  });

  static Future<String?> show(
    BuildContext context, {
    required FolderNode? rootNode,
    String? currentFolderName,
    List<String> currentSelectedTags = const [],
  }) {

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FolderTreePickerModal(
        rootNode: rootNode,
        currentFolderName: currentFolderName,
        currentSelectedTags: currentSelectedTags,
        onFolderSelected: (relPath) => Navigator.of(ctx).pop(relPath),
      ),
    );
  }

  @override
  State<FolderTreePickerModal> createState() => _FolderTreePickerModalState();
}

class _FolderTreePickerModalState extends State<FolderTreePickerModal> {
  String? _selectedRelPath;
  final Set<String> _expandedRelPaths = {};

  @override
  void initState() {
    super.initState();
    // Default select nothing or first available
    _expandAllNodes(widget.rootNode);
  }

  void _expandAllNodes(FolderNode? node) {
    if (node == null) return;
    _expandedRelPaths.add(node.relPath);
    for (final child in node.children) {
      _expandAllNodes(child);
    }
  }

  bool _isFolderDisabled(String relPath) {
    if (relPath == 'ROOT' || relPath.isEmpty) {
      // If all selected items are in root
      return widget.currentSelectedTags.isNotEmpty &&
          widget.currentSelectedTags.every((t) => t == 'ROOT');
    }
    // If all selected items are in this exact folder
    return widget.currentSelectedTags.isNotEmpty &&
        widget.currentSelectedTags.every((t) => t.toLowerCase() == relPath.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x44FFFFFF) : const Color(0x33000000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sc.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(SnapSymbols.drive_file_move_outlined, color: sc.accent, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move to Folder',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select destination folder or subfolder',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Tree View
            Flexible(
              child: widget.rootNode == null || widget.rootNode!.children.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No folders created yet',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            color: sc.muted,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shrinkWrap: true,
                      children: [
                        // ROOT destination tile
                        _buildTreeNode(
                          name: 'ROOT',
                          relPath: 'ROOT',
                          depth: 0,
                          isRoot: true,
                          hasChildren: false,
                          isExpanded: false,
                          sc: sc,
                          isDark: isDark,
                        ),
                        // Children of root
                        ..._buildChildrenList(widget.rootNode!.children, 0, sc, isDark),
                      ],
                    ),
            ),

            const Divider(height: 1),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        side: BorderSide(color: sc.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _selectedRelPath != null
                          ? () => widget.onFolderSelected(_selectedRelPath!)
                          : null,
                      child: const Text(
                        'Move Here',
                        style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w700),
                      ),
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

  List<Widget> _buildChildrenList(
    List<FolderNode> nodes,
    int depth,
    SnapgroveColors sc,
    bool isDark,
  ) {
    final List<Widget> list = [];
    for (final node in nodes) {
      final isExpanded = _expandedRelPaths.contains(node.relPath);
      list.add(
        _buildTreeNode(
          name: node.name,
          relPath: node.relPath,
          depth: depth + 1,
          isRoot: false,
          hasChildren: node.hasChildren,
          isExpanded: isExpanded,
          sc: sc,
          isDark: isDark,
          childCount: node.children.length,
          imageCount: node.totalImageCount,
        ),
      );
      if (node.hasChildren && isExpanded) {
        list.addAll(_buildChildrenList(node.children, depth + 1, sc, isDark));
      }
    }
    return list;
  }

  Widget _buildTreeNode({
    required String name,
    required String relPath,
    required int depth,
    required bool isRoot,
    required bool hasChildren,
    required bool isExpanded,
    required SnapgroveColors sc,
    required bool isDark,
    int childCount = 0,
    int imageCount = 0,
  }) {
    final isSelected = _selectedRelPath == relPath;
    final isDisabled = _isFolderDisabled(relPath);

    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _selectedRelPath = relPath;
              });
            },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.fromLTRB(8 + (depth * 18.0), 6, 12, 6),
        decoration: BoxDecoration(
          color: isSelected ? sc.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? sc.accent.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Expand / Collapse Chevron
            if (hasChildren)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedRelPaths.remove(relPath);
                      } else {
                        _expandedRelPaths.add(relPath);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      isExpanded ? SnapSymbols.keyboard_arrow_down : SnapSymbols.keyboard_arrow_right,
                      size: 20,
                      color: sc.muted,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 26),

            // Icon
            Icon(
              isRoot ? SnapSymbols.home_outlined : (hasChildren ? SnapSymbols.folder : SnapSymbols.folder_outlined),
              size: 20,
              color: isDisabled
                  ? sc.muted.withValues(alpha: 0.4)
                  : (isSelected ? sc.accent : (isDark ? Colors.white70 : Colors.black87)),
            ),
            const SizedBox(width: 10),

            // Name
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isDisabled
                      ? sc.muted.withValues(alpha: 0.4)
                      : (isSelected ? sc.accent : (isDark ? Colors.white : Colors.black87)),
                ),
              ),
            ),

            if (imageCount > 0)
              Text(
                '$imageCount item${imageCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: sc.muted,
                ),
              ),

            // Radio Indicator
            const SizedBox(width: 8),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? sc.accent : sc.border,
                  width: 2,
                ),
                color: isSelected ? sc.accent : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(SnapSymbols.check, size: 12, color: Colors.white),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
