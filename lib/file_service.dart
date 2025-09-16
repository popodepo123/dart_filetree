import 'dart:io';

import 'package:dart_filetree/file_node.dart';

/// Service class for handling file operations
class FileService {
  const FileService();

  /// Lists files in the given directory
  List<FileSystemEntity> listDirectory(Directory directory) {
    try {
      return directory.listSync(recursive: false);
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  /// Creates a new file or directory
  Future<File> createFile(String path, bool isDirectory) async {
    final file = File(path);
    if (isDirectory) {
      await Directory(path).create(recursive: true);
      return file;
    }
    return await file.create(recursive: true, exclusive: true);
  }

  /// Deletes a file or directory
  void deleteFile(String path) {
    final file = File(path);
    file.deleteSync(recursive: true);
  }

  /// Write a content to a file
  /// Crucial for chooser file integration with other TUI IDE
  Future<File?> writeToChooserFile({
    required String chooserFile,
    required String toWrite,
  }) async {
    try {
      return await File(chooserFile).writeAsString(toWrite);
    } catch (e) {
      return null;
    }
  }

  /// Reads file content as string
  String readFileContent(String path) {
    try {
      final file = File(path);
      return file.readAsStringSync();
    } catch (e) {
      return '[Binary file]';
    }
  }

  /// Gets the parent directory path
  String getParentPath(String path) {
    return File(path).parent.path;
  }

  /// Builds the complete file tree from directory
  List<FileNode> buildFileTree(Directory directory, Set<String> expandedPaths) {
    final entities = listDirectory(directory);
    final nodes = entities
        .map((entity) => FileNode(entity, expandedPaths: expandedPaths))
        .toList();

    final files = <FileNode>[];
    for (final node in nodes) {
      files.addAll([node, ...node.children]);
    }

    files.sort((a, b) => a.entity.path.compareTo(b.entity.path));
    return files;
  }
}
