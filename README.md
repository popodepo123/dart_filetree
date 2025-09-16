# dart_filetree

A terminal-based file tree picker built with Dart and nocterm for integration with editors like Helix.

## Core Components

- `lib/file_node.dart` - FileNode class for representing file/directory nodes with expansion state and display formatting
- `lib/file_service.dart` - FileService class providing file operations (list, create, delete, read, write to chooser file)
- `dart_filetree_picker.sh` - Shell script for Helix editor integration via zellij floating panes

## Features

- Interactive file tree navigation in terminal using nocterm UI framework
- File selection and operations with chooser file integration
- Local storage using Hive for settings persistence
- Cross-platform file system operations
- Helix editor integration via zellij for seamless file opening

## Installation

### Prerequisites

- Dart SDK
- FVM (Flutter Version Management) recommended

### Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   fvm dart pub get
   ```

## Usage

### Running the Application

```bash
fvm dart run
```

### Building Executable

```bash
fvm dart compile exe bin/dart_filetree.dart
```

### Using the Picker Script

The included `dart_filetree_picker.sh` script provides integration with Helix editor:

```bash
./dart_filetree_picker.sh
```

This script:
- Creates a temporary file for communication
- Launches the file picker in a zellij floating pane
- Sends the selected file path back to Helix

## Development

### Code Analysis

```bash
fvm dart analyze
```

### Testing

```bash
fvm dart test
```

## Dependencies

- `nocterm` - Terminal UI framework for interactive interface
- `hive` - Local database for settings storage
- `path` - File path manipulation utilities

## Zellij Helix Integration Command

Revise as you wish

```
:sh zellij run -c -f -x 10%% -y 10%% --width 80%% --height 80%% -- bash ~/dart_filetree/dart_filetree_picker.sh open %{buffer_name} 
```

Make sure to place the project in your home directory and that you have compiled the executable 

## License

See LICENSE file for details.
