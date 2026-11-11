class FolderNode {
  final String name;
  final String path; // absolute FS path or content:// URI
  final String relPath; // relative to root, e.g. "Work" or "Work/Receipts"
  final List<FolderNode> children;
  final int directImageCount;
  final int totalImageCount;

  const FolderNode({
    required this.name,
    required this.path,
    required this.relPath,
    this.children = const [],
    this.directImageCount = 0,
    this.totalImageCount = 0,
  });

  bool get hasChildren => children.isNotEmpty;

  FolderNode copyWith({
    String? name,
    String? path,
    String? relPath,
    List<FolderNode>? children,
    int? directImageCount,
    int? totalImageCount,
  }) {
    return FolderNode(
      name: name ?? this.name,
      path: path ?? this.path,
      relPath: relPath ?? this.relPath,
      children: children ?? this.children,
      directImageCount: directImageCount ?? this.directImageCount,
      totalImageCount: totalImageCount ?? this.totalImageCount,
    );
  }

  /// Flattens this node and all descendants into a single list
  List<FolderNode> flatten() {
    final List<FolderNode> list = [this];
    for (final child in children) {
      list.addAll(child.flatten());
    }
    return list;
  }

  /// Finds a node by relPath
  FolderNode? findByRelPath(String targetRelPath) {
    if (relPath == targetRelPath) return this;
    for (final child in children) {
      final found = child.findByRelPath(targetRelPath);
      if (found != null) return found;
    }
    return null;
  }

  /// Finds a node by exact path or uri
  FolderNode? findByPath(String targetPath) {
    if (path == targetPath) return this;
    for (final child in children) {
      final found = child.findByPath(targetPath);
      if (found != null) return found;
    }
    return null;
  }
}
