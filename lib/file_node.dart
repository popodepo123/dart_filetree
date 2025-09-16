import 'dart:io';

/// Represents a file or directory node in the file tree
class FileNode {
  const FileNode(this.entity, {this.expandedPaths = const {}, this.level = 0});

  final Set<String> expandedPaths;
  final FileSystemEntity entity;
  final int level;

  /// Whether this node represents a directory
  bool get isDirectory => entity is Directory;

  /// Whether this directory is expanded in the tree view
  bool get isExpanded => expandedPaths.contains(entity.path);

  /// The display name of the file/directory
  String get name {
    final segments = entity.path.split(Platform.pathSeparator);
    final baseName = segments.last;
    final prefix = _getPrefix();
    final suffix = isDirectory ? '/' : '';
    return '$prefix$baseName$suffix';
  }

  /// The children of this node (empty for files)
  List<FileNode> get children {
    if (!isDirectory || !isExpanded) return [];

    try {
      final directory = Directory(entity.path);
      final entities = directory.listSync(recursive: false);
      final childNodes = entities
          .map(
            (e) => FileNode(e, expandedPaths: expandedPaths, level: level + 1),
          )
          .toList();

      final allChildren = <FileNode>[];
      for (final node in childNodes) {
        allChildren.addAll([node, ...node.children]);
      }
      return allChildren;
    } catch (e) {
      // Return empty list if directory cannot be read
      return [];
    }
  }

  /// Gets the indentation and expansion indicator prefix
  String _getPrefix() {
    if (!isDirectory) return ''.padLeft(2 * (level + 1));

    final indicator = isExpanded ? '-' : '+';
    final prefix = '$indicator ';
    return prefix.padLeft(2 * (level + 1));
  }
}
