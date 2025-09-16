import 'package:dart_filetree/file_node.dart';
import 'package:dart_filetree/file_service.dart';
import 'package:nocterm/nocterm.dart';
import 'dart:io';
import 'package:hive/hive.dart';

// Constants
const String _pathsExpandedKey = 'pathsExpanded';
const String _filetreeSelectedPathKey = 'filetreeSelectedPath';
const String _chooserFilePrefix = '--chooser-file=';
const int _headerHeight = 4;
const int _fileTreeWidth = 30;
const Duration _initialScrollDelay = Duration(milliseconds: 200);
const bool _moveDown = false;
const bool _moveUp = true;

void main(List<String> args) async {
  Hive.init(Directory.current.path);
  final box = await Hive.openBox('settings');
  final chooserFile = _parseChooserFile(args);
  await runApp(FiletreeComponent(box: box, chooserFile: chooserFile));
}

/// Parses the chooser file path from command line arguments
String _parseChooserFile(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith(_chooserFilePrefix)) {
      return arg.substring(_chooserFilePrefix.length);
    }
  }
  return '';
}

class FiletreeComponent extends StatefulComponent {
  const FiletreeComponent({
    super.key,
    required this.box,
    required this.chooserFile,
  });
  final Box box;
  final String chooserFile;

  @override
  State<FiletreeComponent> createState() => _FiletreeComponentState();
}

class _FiletreeComponentState extends State<FiletreeComponent> {
  final ScrollController previewScrollController = ScrollController();
  final ScrollController fileTreeScrollController = ScrollController();
  final TextEditingController textEditingController = TextEditingController();
  final FileService fileService = const FileService();

  Directory directory = Directory.current;
  bool isWritingFileName = false;
  bool isDeletingFile = false;
  double viewportUp = 0;
  double viewportDown = 0;

  Set<String> pathsExpanded = {};
  int pointerIndex = 0;
  List<FileNode> currentFiles = [];
  @override
  void initState() {
    super.initState();
    init();
    initialScroll();
  }

  @override
  void dispose() {
    previewScrollController.dispose();
    fileTreeScrollController.dispose();
    textEditingController.dispose();
    component.box.close();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final currFiles = getCurrFiles();
    return Focusable(
      focused: !isWritingFileName,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        width: getMaxWidth().toDouble(),
        height: getMaxWidth().toDouble(),
        child: SizedBox(
          height: getMaxHeight(),
          width: getMaxWidth(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildStatusBar(currFiles),
              _buildMainContent(),
              if (isWritingFileName || isDeletingFile) _buildInputField(),
            ],
          ),
        ),
      ),
    );
  }

  bool _handleKeyEvent(dynamic event) {
    if (isDeletingFile) {
      return _handleDeleteConfirmation(event);
    }
    return _handleNormalKeyEvent(event);
  }

  bool _handleDeleteConfirmation(dynamic event) {
    switch (event.logicalKey) {
      case LogicalKey.keyY:
      case LogicalKey.enter:
        handleDelete();
        break;
      case LogicalKey.keyN:
        break;
    }
    setState(() {
      textEditingController.text = '';
      isDeletingFile = false;
    });
    return true;
  }

  bool _handleNormalKeyEvent(dynamic event) {
    final currFiles = getCurrFiles();
    switch (event.logicalKey) {
      case LogicalKey.enter:
        handleEnter();
      case LogicalKey.keyJ:
        return movePointerIndex(_moveDown);
      case LogicalKey.keyK:
        return movePointerIndex(_moveUp);
      case LogicalKey.keyA:
        textEditingController.text = '';
        isWritingFileName = true;
        setState(() {});
        return true;
      case LogicalKey.keyL:
        expandPath(currFiles[pointerIndex].entity.path);
        return true;
      case LogicalKey.keyH:
        collapsePath(currFiles[pointerIndex].entity.path);
        return true;
      case LogicalKey.keyD:
        setState(() {
          isDeletingFile = true;
          textEditingController.text =
              'Are you sure you want to delete this file? (Y/y/enter or N/n)';
        });
        return true;
      case LogicalKey.keyW:
        previewScrollController.pageDown();
        return true;
      case LogicalKey.keyB:
        previewScrollController.pageUp();
        return true;
      case LogicalKey.keyQ:
        Terminal().clear();
        exit(0);
    }
    return true;
  }

  Component _buildStatusBar(List<FileNode> currFiles) {
    return Container(
      height: 1,
      alignment: Alignment.centerLeft,
      child: Text(currFiles[pointerIndex].entity.path),
    );
  }

  Component _buildMainContent() {
    return SizedBox(
      height: getMaxHeight() - _headerHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildFileTree(), _buildPreview()],
      ),
    );
  }

  Component _buildInputField() {
    return TextField(
      onFocusChange: (value) {
        if (value) {
          setState(() => isWritingFileName = false);
        }
      },
      focused: isWritingFileName,
      decoration: InputDecoration(border: BoxBorder.all(color: Colors.white)),
      controller: textEditingController,
      onSubmitted: handleCreate,
    );
  }

  Future<void> expandPath(String path) async {
    pathsExpanded.add(path);
    await component.box.put(_pathsExpandedKey, pathsExpanded.join(','));
    _updateFileTree();
  }

  Future<void> collapsePath(String path) async {
    pathsExpanded.remove(path);
    await component.box.put(_pathsExpandedKey, pathsExpanded.join(','));
    _updateFileTree();
  }

  void _updateFileTree() {
    currentFiles = fileService.buildFileTree(directory, pathsExpanded);
    setState(() {});
  }

  List<FileNode> getCurrFiles() {
    if (currentFiles.isEmpty) {
      currentFiles = fileService.buildFileTree(directory, pathsExpanded);
    }
    return currentFiles;
  }

  void init() {
    final storedExpandedPaths =
        component.box.get(_pathsExpandedKey) as String? ?? '';
    pathsExpanded =
        storedExpandedPaths.split(',').where((e) => e.isNotEmpty).toSet();

    final storedSelectedPath =
        component.box.get(_filetreeSelectedPathKey) as String? ?? '';
    final initialPointerIndex = getCurrFiles().indexWhere(
      (node) => node.entity.path == storedSelectedPath,
    );
    if (initialPointerIndex != -1) {
      pointerIndex = initialPointerIndex;
    }
  }

  Future<void> initialScroll() async {
    await Future.delayed(_initialScrollDelay);
    final viewportSize = getViewPortSize();
    final scrollCount = (pointerIndex + 1) - (viewportSize / 2).floor() - 1;
    viewportUp = scrollCount.toDouble() + 1;
    viewportDown = scrollCount + viewportSize;
    fileTreeScrollController.scrollDown(scrollCount.toDouble());
  }

  double getViewPortSize() => getMaxHeight() - _headerHeight - 2;
  double getMaxHeight() => Terminal().size.height;
  double getMaxWidth() => Terminal().size.width;
  bool movePointerIndex(bool up) {
    final viewportSize = getViewPortSize();
    final currFiles = getCurrFiles();

    if (!up) {
      if (pointerIndex >= currFiles.length - 1) return false;
      setState(() => pointerIndex++);
      component.box.put(
        _filetreeSelectedPathKey,
        currFiles[pointerIndex].entity.path,
      );
    } else {
      if (pointerIndex <= 0) return false;
      setState(() => pointerIndex--);
      component.box.put(
        _filetreeSelectedPathKey,
        currFiles[pointerIndex].entity.path,
      );
    }
    _updateScrollPosition(viewportSize);
    return true;
  }

  void _updateScrollPosition(double viewportSize) {
    final itemNum = pointerIndex + 1;
    if (viewportUp - 1 == itemNum) {
      fileTreeScrollController.jumpTo((itemNum - 1).toDouble());
      setState(() {
        viewportUp--;
        viewportDown--;
      });
    }

    if (viewportDown + 1 == itemNum) {
      fileTreeScrollController.jumpTo((itemNum - 1).toDouble());
      setState(() {
        viewportDown += viewportSize;
        viewportUp += viewportSize;
      });
    }
  }

  void handleDelete() {
    final nodes = getCurrFiles();
    if (pointerIndex >= nodes.length) return;

    final node = nodes[pointerIndex];
    try {
      fileService.deleteFile(node.entity.path);
      if (pointerIndex > 0) {
        setState(() => pointerIndex--);
      }
      _updateFileTree();
    } catch (e) {
      // Handle deletion error silently for now
    }
  }

  Future<void> handleCreate(String filename) async {
    final nodes = getCurrFiles();
    if (pointerIndex >= nodes.length) return;

    final node = nodes[pointerIndex];
    try {
      final path = node.isDirectory
          ? '${node.entity.path}/$filename'
          : '${fileService.getParentPath(node.entity.path)}/$filename';

      await fileService.createFile(path, false);
      _updateFileTree();

      // Find and select the newly created file
      final newIndex = currentFiles.indexWhere(
        (thisNode) => thisNode.entity.path == path,
      );

      setState(() {
        if (newIndex != -1) pointerIndex = newIndex;
        textEditingController.text = '';
        isWritingFileName = false;
      });
    } catch (e) {
      // Handle creation error silently for now
      setState(() {
        textEditingController.text = '';
        isWritingFileName = false;
      });
    }
  }

  void handleEnter() {
    final files = getCurrFiles();
    final path = files[pointerIndex].entity.path;
    fileService
        .writeToChooserFile(chooserFile: component.chooserFile, toWrite: path)
        .then((value) {
      if (value == null) exit(69);
      exit(0);
    });
  }

  Component _buildPreview() {
    final nodes = getCurrFiles();
    if (pointerIndex >= nodes.length) return Text('');
    final node = nodes[pointerIndex];
    if (node.isDirectory) return Text('');
    final content = fileService.readFileContent(node.entity.path);
    final lines = content.split('\n');
    return Container(
      width: getMaxWidth() - (_fileTreeWidth.toDouble() + 1),
      decoration: BoxDecoration(border: BoxBorder.all(color: Colors.white)),
      margin: EdgeInsets.only(left: 1),
      child: ListView.builder(
        controller: previewScrollController,
        itemExtent: 1,
        itemCount: lines.length,
        itemBuilder: (context, index) {
          return Row(
            children: [
              Text('${(index + 1).toString().padLeft(4)}: ',
                  style: TextStyle(color: Colors.gray)),
              Expanded(child: Text(lines[index])),
            ],
          );
        },
      ),
    );
  }

  Component _buildFileTree() {
    final files = getCurrFiles();
    return Container(
      decoration: BoxDecoration(border: BoxBorder.all(color: Colors.white)),
      width: _fileTreeWidth.toDouble(),
      child: SingleChildScrollView(
        controller: fileTreeScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            for (int i = 0; i < files.length; i++)
              Text(
                files[i].name,
                style: TextStyle(
                  color: pointerIndex == i ? Colors.yellow : Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
